#!/usr/bin/env bash
# =============================================================================
# Company Root CA — Linux device installer
#
# Installs the Company Root CA (CN=root-ca, O=Company) into every trust store
# a Linux device needs, and REMOVES any retired block-page root CA it finds:
#   1. System CA certificate store  (curl / openssl / most CLI tools)
#   2. Browser NSS store            (Google Chrome, apt Chromium, Edge, ...)
#   3. snap Chromium NSS store      (snap Chromium — isolated db)
#
# Safety model:
#   * The expected SHA-256 fingerprint is PINNED below. The script refuses to
#     install anything that does not match it (fail-closed).
#   * Every store is verified AFTER install — the fingerprint of what actually
#     landed in the store must match the pin.
#   * Retired CAs (old AdORSYS block-page root, previous company roots) are
#     removed by FINGERPRINT/SUBJECT, not by nickname or path, so they are
#     always cleaned up even if installed under a different name.
#   * Idempotent: re-running is a no-op when the pinned CA is already present.
#   * Browser NSS DBs are never wiped — only targeted entries are removed.
#
# Requirements:
#   - sudo
#   - certutil (libnss3-tools) — auto-installed via apt when NSS stores exist
#   - curl (to fetch the certificate from GitHub)
#
# Usage:
#   sudo ./linux-ca-install.sh
#   sudo CA_BRANCH=dns-block ./linux-ca-install.sh
#   CA_CRT=/path/to/ca.crt sudo ./linux-ca-install.sh   # override: local file
#   ./linux-ca-install.sh --check [path/to/ca.crt]      # validate only, no install
#
# Environment variables:
#   CA_BRANCH  — Git branch to fetch the cert from (default: main).
#                NOTE: when running via sudo, set it AFTER sudo so it is
#                passed through:  sudo CA_BRANCH=<branch> ./linux-ca-install.sh
#                (or: export CA_BRANCH=<branch> && sudo -E ./linux-ca-install.sh)
#   CA_CRT     — Path to a local .crt file (skips fetch if set)
#
# NOTE: Browser NSS databases are always created WITHOUT a password
# (empty password + explicit -f pwfile), so certutil never prompts.
#
# NOTE: Firefox is NOT supported for now (not allowed in the company).
# Firefox uses its own NSS store and would need separate handling — revisit later.
# =============================================================================

set -euo pipefail

# --- Pinned trust anchor -----------------------------------------------------
# SHA-256 fingerprint (lowercase, no colons) of the ONLY root CA we install.
# When the CA is rotated, update this pin AND add the old fingerprint to
# RETIRED_SHA256 below — the script then replaces old with new everywhere.
EXPECTED_SHA256="3bcd29906e384d66452171fc37f61d74b02ce22c407e5dcd6da85ce7dd2a5477"
EXPECTED_CN="root-ca"

# Retired block-page root CAs — removed from every store, by fingerprint.
RETIRED_SHA256=(
  "43623b8212aaedd1045317b7a17257f11082b36969e1d78ceeff76f3cfcc3885"  # AdORSYS Block Page Root CA
)
# Retired subjects (substring match, lowercase) — belt & braces for CAs whose
# fingerprint is not in the list above.
RETIRED_SUBJECTS=(
  "adorsys block page root ca"
)

CERT_NICKNAME="Company Root CA"          # NSS nickname
CERT_FILENAME="company-root-ca.crt"      # system-store filename

info()  { echo -e "\033[1;32m[INFO]\033[0m  $*"; }
warn()  { echo -e "\033[1;33m[WARN]\033[0m  $*" >&2; }
die()   { echo -e "\033[1;31m[ERROR]\033[0m $*" >&2; exit 1; }

# GitHub raw content base URL for the certificate
GITHUB_RAW_URL="https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent"
CERT_PATH_IN_REPO="scripts/block-dns/company-root-ca.crt"

# Run a command with sudo only if not already root
if [ "$(id -u)" -eq 0 ]; then
  maybe_sudo() { "$@"; }
else
  maybe_sudo() { sudo "$@"; }
fi

# Some DB writes run as root (via sudo); hand the user's DBs back to the user.
# Safe as non-root too (chown to self is a no-op).
_own() {
  chown -R "${REAL_USER}" "$@" 2>/dev/null || true
}

# Empty NSS password file — keeps certutil 100% non-interactive
PWFILE=$(mktemp /tmp/nss-pw.XXXXXX)
: > "${PWFILE}"

# Temp file for the fetched certificate
CERT_TMPFILE=$(mktemp /tmp/company-root-ca.XXXXXX.crt)

# Cleanup temp files on exit
trap 'rm -f "${PWFILE}" "${CERT_TMPFILE}"' EXIT

# --- Detect real user home (works even via sudo) ---
# sudo resets $HOME to /root; we need the actual user's HOME for browser NSS paths
REAL_USER="${SUDO_USER:-$(logname 2>/dev/null || echo "${USER:-$(id -un)}")}"
REAL_USER_HOME=$(getent passwd "${REAL_USER}" 2>/dev/null | cut -d: -f6)
REAL_USER_HOME="${REAL_USER_HOME:-${HOME:-/root}}"

NSSDB="${REAL_USER_HOME}/.pki/nssdb"

# --- Fingerprint / subject helpers -------------------------------------------
norm_fp() {
  tr -d ':' | tr '[:upper:]' '[:lower:]' | sed 's/^sha256 fingerprint=//'
}

cert_fp() {
  openssl x509 -in "$1" -noout -fingerprint -sha256 2>/dev/null | norm_fp || true
}

cert_subject() {
  openssl x509 -in "$1" -noout -subject 2>/dev/null \
    | sed 's/^subject=//' | tr '[:upper:]' '[:lower:]' | tr -s ' ' || true
}

is_ca() {
  openssl x509 -in "$1" -noout -text 2>/dev/null | grep -q "CA:TRUE"
}

is_retired_fp() {
  local fp="$1" r
  [ -n "$fp" ] || return 1
  for r in "${RETIRED_SHA256[@]}"; do
    [ "$fp" = "$r" ] && return 0
  done
  return 1
}

is_retired_subject() {
  local subj="$1" s
  [ -n "$subj" ] || return 1
  for s in "${RETIRED_SUBJECTS[@]}"; do
    [[ "$subj" == *"$s"* ]] && return 0
  done
  return 1
}

# Full gate: the file must be a CA cert whose SHA-256 matches the pin.
check_cert() {
  local file="$1" fp
  [ -f "${file}" ] || die "File not found: ${file}"
  [ -s "${file}" ] || die "File is empty: ${file}"
  head -1 "${file}" | grep -q "BEGIN CERTIFICATE" || die "Not a PEM certificate: ${file}"
  openssl x509 -in "${file}" -noout >/dev/null 2>&1 || die "Not a valid X.509 certificate: ${file}"
  is_ca "${file}" || die "Not a CA certificate (basicConstraints CA:TRUE missing): ${file}"
  fp=$(cert_fp "${file}")
  [ -n "${fp}" ] || die "Could not compute fingerprint: ${file}"
  if [ "${fp}" != "${EXPECTED_SHA256}" ]; then
    die "Fingerprint mismatch — refusing to install.
  expected : ${EXPECTED_SHA256}  (${EXPECTED_CN})
  got      : ${fp}
If the CA was rotated, update EXPECTED_SHA256 in this script."
  fi
  info "Fingerprint verified ✔  ${fp}"
}

# --- Input: mode + CA certificate --------------------------------------------
MODE="install"
CA_FILE=""
if [ "${1:-}" = "--check" ] || [ "${1:-}" = "-c" ]; then
  MODE="check"
  CA_FILE="${2:-}"
elif [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  sed -n '2,45p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
fi

CA_BRANCH="${CA_BRANCH:-main}"

if [ -n "${CA_FILE}" ] || [ -n "${CA_CRT:-}" ]; then
  CA_FILE="${CA_FILE:-${CA_CRT}}"
  info "Using local certificate file: ${CA_FILE}"
  case "${CA_FILE}" in
    /*) ;;
    "~/"*) CA_FILE="${REAL_USER_HOME}/${CA_FILE:2}" ;;
    "~"*) CA_FILE="${REAL_USER_HOME}${CA_FILE:1}" ;;
    *)   CA_FILE="${REAL_USER_HOME}/${CA_FILE}" ;;
  esac
else
  FETCH_URL="${GITHUB_RAW_URL}/${CA_BRANCH}/${CERT_PATH_IN_REPO}"
  info "Fetching certificate from GitHub (branch: ${CA_BRANCH})..."
  info "URL: ${FETCH_URL}"
  if ! command -v curl >/dev/null 2>&1; then
    die "curl is required but not installed. Please install curl and retry."
  fi
  HTTP_CODE=$(curl -sS -w "%{http_code}" -o "${CERT_TMPFILE}" "${FETCH_URL}" 2>/dev/null) || true
  if [ "${HTTP_CODE}" != "200" ]; then
    die "Failed to fetch certificate (HTTP ${HTTP_CODE}). Check branch '${CA_BRANCH}' and try again."
  fi
  CA_FILE="${CERT_TMPFILE}"
fi

check_cert "${CA_FILE}"

if [ "${MODE}" = "check" ]; then
  info "OK — ${CA_FILE} is the pinned Company Root CA (${EXPECTED_CN})"
  exit 0
fi

# -----------------------------------------------------------------------------
# 1. System CA certificate store
# -----------------------------------------------------------------------------
info "Installing into system certificate store..."

# Remove retired CAs (by fingerprint/subject) from every system CA dir
for dir in /usr/local/share/ca-certificates /etc/pki/ca-trust/source/anchors; do
  [ -d "${dir}" ] || continue
  while IFS= read -r -d '' file; do
    fp=$(cert_fp "${file}")
    subj=$(cert_subject "${file}")
    if is_retired_fp "${fp}" || is_retired_subject "${subj}"; then
      warn "Removing retired CA: ${file}"
      maybe_sudo rm -f "${file}"
    fi
  done < <(find "${dir}" -maxdepth 1 -type f \( -name '*.crt' -o -name '*.pem' \) -print0 2>/dev/null)
done

# Stale hardcoded paths from older installers
for stale in /usr/local/share/ca-certificates/adorsys-block.crt \
             /usr/local/share/ca-certificates/adorsys-block-page-ca.crt; do
  if [ -f "${stale}" ]; then
    warn "Removing stale CA: ${stale}"
    maybe_sudo rm -f "${stale}"
  fi
done

DEST="/usr/local/share/ca-certificates/${CERT_FILENAME}"

# Idempotent: skip copy+rebuild if the pinned cert is already in place
if [ "$(cert_fp "${DEST}")" = "${EXPECTED_SHA256}" ]; then
  info "System store already has the pinned CA — skipping copy"
else
  maybe_sudo cp "${CA_FILE}" "${DEST}"
  maybe_sudo chmod 644 "${DEST}"
  if command -v update-ca-certificates >/dev/null 2>&1; then
    maybe_sudo update-ca-certificates 2>&1 | grep -v "^trust_settings" || true
  elif command -v update-ca-trust >/dev/null 2>&1; then
    maybe_sudo update-ca-trust extract 2>&1 || true
  else
    warn "No update-ca-certificates/update-ca-trust found — bundle not rebuilt"
  fi
fi

# Verify AFTER install: fingerprint of what actually landed in the store
if [ "$(cert_fp "${DEST}")" = "${EXPECTED_SHA256}" ]; then
  info "System store verified ✔  ${DEST}"
else
  die "System store verification failed: ${DEST}"
fi

# -----------------------------------------------------------------------------
# 2. certutil (NSS tools)
# -----------------------------------------------------------------------------
if ! command -v certutil >/dev/null 2>&1; then
  info "certutil not found — installing libnss3-tools..."
  maybe_sudo apt-get update -qq && maybe_sudo apt-get install -y libnss3-tools \
    || die "Failed to install libnss3-tools"
  info "libnss3-tools installed ✔"
fi

# --- NSS helpers ---------------------------------------------------------------
nss_list_nicknames() {
  local db="$1"
  # certutil -L pads with spaces (not tabs); split on 2+ spaces
  certutil -L -d "sql:${db}" -f "${PWFILE}" 2>/dev/null \
    | awk -F'  +' 'NF >= 2 && $1 != "" && $1 !~ /Certificate Nickname/ { print $1 }'
}

nss_cert_fp() {
  local db="$1" nick="$2"
  certutil -L -d "sql:${db}" -n "${nick}" -a -f "${PWFILE}" 2>/dev/null \
    | openssl x509 -noout -fingerprint -sha256 2>/dev/null | norm_fp || true
}

nss_cert_subject() {
  local db="$1" nick="$2"
  certutil -L -d "sql:${db}" -n "${nick}" -a -f "${PWFILE}" 2>/dev/null \
    | openssl x509 -noout -subject 2>/dev/null \
    | sed 's/^subject=//' | tr '[:upper:]' '[:lower:]' | tr -s ' ' || true
}

nss_has_pinned() {
  local db="$1" nick fp
  while IFS= read -r nick; do
    [ -n "${nick}" ] || continue
    fp=$(nss_cert_fp "${db}" "${nick}")
    [ "${fp}" = "${EXPECTED_SHA256}" ] && return 0
  done < <(nss_list_nicknames "${db}")
  return 1
}

# Install into one NSS db: remove retired entries, add pinned if missing, verify.
nss_install_db() {
  local db="$1" nick fp subj
  [ -d "${db}" ] || return 1
  mkdir -p "${db}"

  if [ ! -f "${db}/cert9.db" ]; then
    certutil -N -d "sql:${db}" --empty-password -f "${PWFILE}" 2>/dev/null || return 1
  fi

  # 1. Remove retired CAs by fingerprint/subject (any nickname)
  while IFS= read -r nick; do
    [ -n "${nick}" ] || continue
    fp=$(nss_cert_fp "${db}" "${nick}")
    subj=$(nss_cert_subject "${db}" "${nick}")
    if is_retired_fp "${fp}" || is_retired_subject "${subj}"; then
      warn "Removing retired CA from NSS db: ${nick}"
      certutil -d "sql:${db}" -D -n "${nick}" -f "${PWFILE}" 2>/dev/null || true
    fi
  done < <(nss_list_nicknames "${db}")

  # 2. Add the pinned CA if not already present (idempotent)
  if nss_has_pinned "${db}"; then
    info "Already installed (fingerprint match): ${db}"
  else
    certutil -d "sql:${db}" -D -n "${CERT_NICKNAME}" -f "${PWFILE}" 2>/dev/null || true
    certutil -d "sql:${db}" -A -t "CT,," -n "${CERT_NICKNAME}" -i "${CA_FILE}" -f "${PWFILE}" \
      || { warn "Import failed: ${db} — close the browser and re-run"; return 1; }
  fi

  # 3. Verify AFTER install
  if nss_has_pinned "${db}"; then
    info "NSS store verified ✔  ${db}"
  else
    warn "NSS verification failed: ${db}"
    return 1
  fi
}

# -----------------------------------------------------------------------------
# 3. Browser NSS store (~/.pki/nssdb)
# -----------------------------------------------------------------------------
info "Installing into browser NSS store (Chrome, Edge, Chromium, etc.)..."
nss_install_db "${NSSDB}" || warn "Browser NSS store update failed"
_own "${NSSDB}"

# -----------------------------------------------------------------------------
# 4. snap Chromium NSS store
# -----------------------------------------------------------------------------
info "Checking snap Chromium..."

SNAP_BASE="${REAL_USER_HOME}/snap/chromium"
SNAP_CURRENT=""

if [ -d "${SNAP_BASE}" ] && [ -L "${SNAP_BASE}/current" ]; then
  SNAP_CURRENT=$(readlink -f "${SNAP_BASE}/current" 2>/dev/null)
fi

if [ -z "${SNAP_CURRENT}" ]; then
  info "snap Chromium not found — skipping"
else
  SNAP_NSSDB="${SNAP_CURRENT}/.local/share/pki/nssdb"
  if nss_install_db "${SNAP_NSSDB}"; then
    info "  (snap Chromium rev: $(basename "${SNAP_CURRENT}"))"
  else
    warn "snap Chromium update failed — close Chromium and re-run"
  fi
  _own "${SNAP_NSSDB}"
fi

# NOTE: Firefox is NOT supported for now (not allowed in the company).
# Firefox uses its own NSS store and would need separate handling — revisit later.

info "Company Root CA installed successfully ✔"