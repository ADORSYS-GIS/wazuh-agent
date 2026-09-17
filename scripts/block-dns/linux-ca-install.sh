#!/usr/bin/env bash
# =============================================================================
# AdORSYS Block-Page CA — Linux device installer
#
# Installs the AdORSYS Block Page Root CA into all three trust stores a Linux
# device needs:
#   1. System CA certificate store  (curl / openssl / most CLI tools)
#   2. Browser NSS store            (Google Chrome, apt Chromium, Edge, etc.)
#   3. snap Chromium NSS store      (snap Chromium — isolated db)
#
# Requirements:
#   - sudo
#   - certutil (libnss3-tools) — script will prompt to install if missing
#   - curl (to fetch the certificate from GitHub)
#
# Usage:
#   sudo ./linux-ca-install.sh
#   sudo CA_BRANCH=dns-block ./linux-ca-install.sh
#   CA_CRT=/path/to/ca.crt sudo ./linux-ca-install.sh   # override: local file
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
# =============================================================================

set -euo pipefail

info()  { echo -e "\033[1;32m[INFO]\033[0m  $*"; }
warn()  { echo -e "\033[1;33m[WARN]\033[0m  $*" >&2; }
die()   { echo -e "\033[1;31m[ERROR]\033[0m $*" >&2; exit 1; }

# GitHub raw content base URL for the certificate
GITHUB_RAW_URL="https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent"
CERT_PATH_IN_REPO="scripts/block-dns/adorsys-block-page-ca.crt"

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
CERT_TMPFILE=$(mktemp /tmp/adorsys-block-ca.XXXXXX.crt)

# Cleanup temp files on exit
trap 'rm -f "${PWFILE}" "${CERT_TMPFILE}"' EXIT

# --- Detect real user home (works even via sudo) ---
# sudo resets $HOME to /root; we need the actual user's HOME for browser NSS paths
REAL_USER="${SUDO_USER:-$(logname 2>/dev/null || echo "${USER:-$(id -un)}")}"
REAL_USER_HOME=$(getent passwd "${REAL_USER}" 2>/dev/null | cut -d: -f6)
REAL_USER_HOME="${REAL_USER_HOME:-${HOME:-/root}}"

STALE_CA_FILE="/usr/local/share/ca-certificates/adorsys-block.crt"
NSSDB="${REAL_USER_HOME}/.pki/nssdb"

# --- Step 1: Obtain the CA certificate ---
CA_BRANCH="${CA_BRANCH:-main}"

if [ -n "${CA_CRT:-}" ]; then
  # User provided a local file — use it directly
  info "Using local certificate file: ${CA_CRT}"
  CA_FILE="${CA_CRT}"

  # Expand ~ to real user home, resolve relative paths
  case "${CA_FILE}" in
    /*) ;;
    "~/"*) CA_FILE="${REAL_USER_HOME}/${CA_FILE:2}" ;;
    "~"*) CA_FILE="${REAL_USER_HOME}${CA_FILE:1}" ;;
    *)   CA_FILE="${REAL_USER_HOME}/${CA_FILE}" ;;
  esac
else
  # Fetch from GitHub
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

  # Validate the downloaded file
  [ -s "${CERT_TMPFILE}" ] || die "Downloaded certificate is empty."
  head -1 "${CERT_TMPFILE}" | grep -q "BEGIN CERTIFICATE" \
    || die "Downloaded file is not a valid PEM certificate."

  info "Certificate fetched successfully ✔"
  info "Stored temporarily at: ${CERT_TMPFILE}"

  # Use the tmp file as the source for the rest of the install.
  # Section 1 below copies it to the system CA store and verifies.
  CA_FILE="${CERT_TMPFILE}"
fi

# -----------------------------------------------------------------------------
# 0. Validate input file
# -----------------------------------------------------------------------------
[ -f "${CA_FILE}" ] || die "File not found: ${CA_FILE}"
[ -s "${CA_FILE}" ] || die "File is empty: ${CA_FILE}"

# Basic PEM check
head -1 "${CA_FILE}" | grep -q "BEGIN CERTIFICATE" \
  || die "Not a PEM certificate: ${CA_FILE}"

# Grab the CN for friendly output
CA_CN=$(openssl x509 -in "${CA_FILE}" -noout -subject 2>/dev/null \
  | sed 's/subject=//' | tr -d ' ' | grep -o 'CN=[^,]*' | sed 's/CN=//')
CA_FP=$(openssl x509 -in "${CA_FILE}" -noout -fingerprint -sha256 2>/dev/null \
  | tr -d ':' | tr '[:upper:]' '[:lower:]' | grep -o 'sha256.*')

info "CA subject : ${CA_CN}"
info "CA file    : ${CA_FILE}"

# -----------------------------------------------------------------------------
# 1. System CA certificate store
# -----------------------------------------------------------------------------
info "Installing into system certificate store..."

# Remove stale CA if present
if [ -f "${STALE_CA_FILE}" ]; then
  warn "Removing stale CA: ${STALE_CA_FILE}"
  maybe_sudo rm -f "${STALE_CA_FILE}"
fi

# Copy to system ca-certificates dir
DEST="/usr/local/share/ca-certificates/$(basename "${CA_FILE}")"
maybe_sudo cp "${CA_FILE}" "${DEST}"
maybe_sudo chmod 644 "${DEST}"

# Rebuild trust store
maybe_sudo update-ca-certificates 2>&1 | grep -v "^trust_settings" || true

# Verify the copy landed and matches the source
if [ -f "${DEST}" ] && diff -q "${CA_FILE}" "${DEST}" >/dev/null 2>&1 \
   && openssl x509 -in "${DEST}" -noout 2>/dev/null; then
  info "System store updated ✔"
  info "Certificate copied and verified at ${DEST} ✔"
else
  die "System store install failed"
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

# -----------------------------------------------------------------------------
# 3. Browser NSS store (~/.pki/nssdb) — fresh, empty-password
# -----------------------------------------------------------------------------
info "Installing into browser NSS store (Chrome, Edge, Chromium, etc.)..."

mkdir -p "${NSSDB}"

# Always back up + recreate a fresh empty-password DB so certutil never prompts
# and there is never a password on the DB. Prior content (user-added CAs) is
# preserved in the .bak copy for manual recovery.
if [ -e "${NSSDB}/cert9.db" ]; then
  BAK="${NSSDB}.bak.$(date +%Y%m%d%H%M%S)"
  cp -r "${NSSDB}" "${BAK}"
  info "Backed up existing NSS DB to ${BAK}"
  rm -rf "${NSSDB:?}"
  mkdir -p "${NSSDB}"
fi

if [ ! -f "${NSSDB}/cert9.db" ]; then
  certutil -N -d sql:"${NSSDB}" --empty-password -f "${PWFILE}" \
    || die "Failed to create NSS DB at ${NSSDB}"
fi

certutil -d sql:"${NSSDB}" -D -n "AdORSYS Block Page Root CA" \
  -f "${PWFILE}" 2>/dev/null || true

certutil -d sql:"${NSSDB}" -A \
  -t "CT,," \
  -n "AdORSYS Block Page Root CA" \
  -i "${CA_FILE}" \
  -f "${PWFILE}" \
  || die "Failed to import into ${NSSDB}"

if certutil -d sql:"${NSSDB}" -L -f "${PWFILE}" 2>/dev/null | grep -qi "adorsys"; then
  info "Browser NSS store updated: ${NSSDB} ✔"
else
  warn "Browser NSS: AdORSYS root not found — check certutil output above"
fi

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
  mkdir -p "${SNAP_NSSDB}"

  # Recreate fresh empty-password DB (no prompts, no password)
  if [ -e "${SNAP_NSSDB}/cert9.db" ]; then
    SNAP_BAK="${SNAP_NSSDB}.bak.$(date +%Y%m%d%H%M%S)"
    cp -r "${SNAP_NSSDB}" "${SNAP_BAK}"
    info "Backed up snap Chromium NSS DB to ${SNAP_BAK}"
    rm -rf "${SNAP_NSSDB:?}"
    mkdir -p "${SNAP_NSSDB}"
  fi

  if [ ! -f "${SNAP_NSSDB}/cert9.db" ]; then
    certutil -N -d sql:"${SNAP_NSSDB}" --empty-password -f "${PWFILE}" \
      || warn "Failed to create snap Chromium NSS DB"
  fi

  certutil -d sql:"${SNAP_NSSDB}" -D -n "AdORSYS Block Page Root CA" \
    -f "${PWFILE}" 2>/dev/null || true

  certutil -d sql:"${SNAP_NSSDB}" -A \
    -t "CT,," \
    -n "AdORSYS Block Page Root CA" \
    -i "${CA_FILE}" \
    -f "${PWFILE}" \
    || warn "snap Chromium import failed — close Chromium then re-run"

  if certutil -d sql:"${SNAP_NSSDB}" -L -f "${PWFILE}" 2>/dev/null | grep -qi "adorsys"; then
    info "snap Chromium NSS store updated: ${SNAP_NSSDB} ✔"
    info "  (snap Chromium rev: $(basename "${SNAP_CURRENT}"))"
  else
    warn "snap Chromium: root not verified — close it and re-run if needed"
  fi

  _own "${SNAP_NSSDB}"
fi

# -----------------------------------------------------------------------------
# 5. Firefox NSS store (snap / apt / Mozilla tarball — all install types)
# -----------------------------------------------------------------------------
info "Checking Firefox..."

FIREFOX_BASE="${REAL_USER_HOME}/snap/firefox"
FIREFOX_FOUND=0

_ff_add_profile() {
  _dir="$1"
  [ -d "${_dir}" ] || return 1
  _nssdb="${_dir}cert9.db"

  if [ ! -f "${_nssdb}" ]; then
    certutil -N -d sql:"${_dir}" --empty-password -f "${PWFILE}" 2>/dev/null || true
  fi

  certutil -d sql:"${_dir}" -D -n "AdORSYS Block Page Root CA" \
    -f "${PWFILE}" 2>/dev/null || true

  certutil -d sql:"${_dir}" -A \
    -t "CT,," \
    -n "AdORSYS Block Page Root CA" \
    -i "${CA_FILE}" \
    -f "${PWFILE}" \
    || {
      warn "Firefox profile $(basename "${_dir}") import failed"
      return 1
    }

  if certutil -d sql:"${_dir}" -L -f "${PWFILE}" 2>/dev/null | grep -qi "adorsys"; then
    info "Firefox profile: $(basename "${_dir}") ✔"
    FIREFOX_FOUND=1
  fi

  _own "${_dir}"
}

# snap Firefox
if [ -d "${FIREFOX_BASE}/common/.mozilla/firefox" ]; then
  for PROFILE_DIR in "${FIREFOX_BASE}/common/.mozilla/firefox"/*/; do
    _ff_add_profile "${PROFILE_DIR}" || true
  done
fi

# apt / Mozilla DEB Firefox
APT_FIREFOX_BASE="${REAL_USER_HOME}/.mozilla/firefox"
if [ -d "${APT_FIREFOX_BASE}" ]; then
  for PROFILE_DIR in "${APT_FIREFOX_BASE}"/*/; do
    _ff_add_profile "${PROFILE_DIR}" || true
  done
fi

# Mozilla official tarball / Firefox Download
CONFIG_FIREFOX_BASE="${REAL_USER_HOME}/.config/mozilla/firefox"
if [ -d "${CONFIG_FIREFOX_BASE}" ]; then
  for PROFILE_DIR in "${CONFIG_FIREFOX_BASE}"/*/; do
    _ff_add_profile "${PROFILE_DIR}" || true
  done
fi

if [ "${FIREFOX_FOUND}" -eq 0 ]; then
  info "Firefox not found or no profiles — skipping. Install and re-run to enable."
fi

info "AdORSYS Block-Page CA installed successfully ✔"
