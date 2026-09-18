#!/usr/bin/env bash
# =============================================================================
# AdORSYS Block-Page CA — Linux device installer
#
# Installs the AdORSYS Block Page Root CA into all trust stores a Linux device
# needs — in one command:
#   1. System CA certificate store  (curl / openssl / OS TLS)
#   2. Browser NSS store            (Chrome, Edge, Chromium, Brave, Opera, etc.)
#   3. snap Chromium NSS store      (snap Chromium — isolated per-revision db)
#   4. Firefox NSS store            (all profiles: snap + apt + Mozilla tarball)
#
# Requirements:
#   - sudo
#   - certutil (libnss3-tools) — script prompts to install if missing
#
# One command — everything downloads automatically:
#   curl -sL https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-helm/feat/adguard-helm-prod/charts/adguard/block-proxy/scripts/linux-ca-install.sh | sudo bash
# =============================================================================

set -euo pipefail

# BASH_SOURCE is unset when bash reads via stdin/pipe — must init before set -u
# is evaluated.
: "${BASH_SOURCE:=['']}"

SCRIPT_BRANCH="${SCRIPT_BRANCH:-dns-block}"
REPO_RAW="https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/${SCRIPT_BRANCH}/scripts/linux/ca-installer"
REPO_API="https://api.github.com/repos/ADORSYS-GIS/wazuh-agent/contents/scripts/linux/ca-installer"

info()  { echo -e "\033[1;32m[INFO]\033[0m  $*"; }
warn()  { echo -e "\033[1;33m[WARN]\033[0m  $*" >&2; }
die()   { echo -e "\033[1;31m[ERROR]\033[0m $*" >&2; exit 1; }

# --- Detect real user home (works even via sudo) ---
REAL_USER_HOME=$(getent passwd "$(logname 2>/dev/null || echo "$USER")" 2>/dev/null \
  | cut -d: -f6)
REAL_USER_HOME="${REAL_USER_HOME:-${HOME}}"

STALE_CA_FILE="/usr/local/share/ca-certificates/adorsys-block.crt"
NSSDB="${REAL_USER_HOME}/.pki/nssdb"

# --- CA cert path — auto-detect or download from GitHub ---
CA_FILE=""
if [ -n "${1:-}" ] && [ -f "${1}" ]; then
  CA_FILE="${1}"
elif [ -n "${CA_CRT:-}" ] && [ -f "${CA_CRT}" ]; then
  CA_FILE="${CA_CRT}"
else
  SCRIPT_DIR=""
  if [ -n "${BASH_SOURCE+x}" ] && [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  elif [ -n "${0}" ] && [ "${0}" != "-bash" ] && [ "${0}" != "bash" ] && [ -f "${0}" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"
  fi
  for candidate in \
    "${SCRIPT_DIR}/adorsys-block-page-ca.crt" \
    "${SCRIPT_DIR}/../adorsys-block-page-ca.crt" \
    "${REAL_USER_HOME}/adorsys-block-page-ca.crt"; do
    [ -f "${candidate}" ] && CA_FILE="${candidate}" && break
  done
fi

# Download from GitHub if not found locally
if [ -z "${CA_FILE}" ] || [ ! -f "${CA_FILE}" ]; then
  info "Downloading AdORSYS CA certificate..."
  CA_FILE="${REAL_USER_HOME}/adorsys-block-page-ca.crt"

  # Try raw URL first (works for public repos)
  _downloaded=0
  if curl -sL "${REPO_RAW}/adorsys-block-page-ca.crt" -o "${CA_FILE}" --fail 2>/dev/null; then
    _downloaded=1
  fi

  # For private repos: use GitHub API with a token from GITHUB_TOKEN env var
  if [ "${_downloaded}" -eq 0 ] && [ -n "${GITHUB_TOKEN:-}" ]; then
    _content=$(curl -sL \
      -H "Authorization: Bearer ${GITHUB_TOKEN}" \
      -H "Accept: application/vnd.github.raw+json" \
      "${REPO_API}/adorsys-block-page-ca.crt" 2>/dev/null)
    if [ -n "${_content}" ]; then
      echo "${_content}" > "${CA_FILE}"
      _downloaded=1
    fi
  fi

  if [ "${_downloaded}" -eq 0 ]; then
    die "Failed to download CA certificate. For private repos, set GITHUB_TOKEN env var.
  For managed devices: the CA is distributed via the Wazuh agent enrollment flow."
  fi

  [ -s "${CA_FILE}" ] || die "CA certificate downloaded but is empty."
  info "CA cert saved to: ${CA_FILE}"
fi

# CA_FILE is now always absolute — ensure it
case "${CA_FILE}" in
  /*) ;;
  "~"*) CA_FILE="${REAL_USER_HOME}${CA_FILE:1}" ;;
  *)   CA_FILE="${REAL_USER_HOME}/${CA_FILE}" ;;
esac

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
  sudo rm -f "${STALE_CA_FILE}"
fi

# Copy to system ca-certificates dir
DEST="/usr/local/share/ca-certificates/$(basename "${CA_FILE}")"
sudo cp "${CA_FILE}" "${DEST}"
sudo chmod 644 "${DEST}"

# Rebuild trust store
sudo update-ca-certificates 2>&1 | grep -v "^trust_settings" || true

# Verify
if openssl x509 -in "${DEST}" -noout 2>/dev/null; then
  info "System store updated ✔"
else
  die "System store install failed"
fi

# -----------------------------------------------------------------------------
# 2. certutil (NSS tools)
# -----------------------------------------------------------------------------
if ! command -v certutil >/dev/null 2>&1; then
  info "certutil not found — installing libnss3-tools..."
  sudo apt-get update -qq && sudo apt-get install -y libnss3-tools \
    || die "Failed to install libnss3-tools"
  info "libnss3-tools installed ✔"
fi

# -----------------------------------------------------------------------------
# 3. Browser NSS store (~/.pki/nssdb)
# -----------------------------------------------------------------------------
info "Installing into browser NSS store (Chrome, Edge, Chromium, etc.)..."

mkdir -p "${NSSDB}"

# Remove stale entry first (safe to fail silently)
certutil -d sql:"${NSSDB}" -D -n "AdORSYS Block Page Root CA" 2>/dev/null || true

# Import
certutil -d sql:"${NSSDB}" -A \
  -t "CT,," \
  -n "AdORSYS Block Page Root CA" \
  -i "${CA_FILE}" \
  || die "Failed to import into ${NSSDB}"

if certutil -d sql:"${NSSDB}" -L 2>/dev/null | grep -qi "adorsys"; then
  info "Browser NSS store updated: ${NSSDB} ✔"
else
  warn "Browser NSS: AdORSYS root not found — check certutil output above"
fi

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

  # Remove stale entry
  certutil -d sql:"${SNAP_NSSDB}" -D -n "AdORSYS Block Page Root CA" 2>/dev/null || true

  echo -n "" >/dev/null

  certutil -d sql:"${SNAP_NSSDB}" -A \
    -t "CT,," \
    -n "AdORSYS Block Page Root CA" \
    -i "${CA_FILE}" \
    || warn "snap Chromium import failed — close Chromium then re-run"

  if certutil -d sql:"${SNAP_NSSDB}" -L 2>/dev/null | grep -qi "adorsys"; then
    info "snap Chromium NSS store updated: ${SNAP_NSSDB} ✔"
    info "  (snap Chromium rev: $(basename "${SNAP_CURRENT}"))"
  else
    warn "snap Chromium: root not verified — close it and re-run if needed"
  fi
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
    certutil -N -d sql:"${_dir}" --empty-password 2>/dev/null || true
  fi

  certutil -d sql:"${_dir}" -D -n "AdORSYS Block Page Root CA" 2>/dev/null || true

  certutil -d sql:"${_dir}" -A \
    -t "CT,," \
    -n "AdORSYS Block Page Root CA" \
    -i "${CA_FILE}" \
    || {
      warn "Firefox profile $(basename "${_dir}") import failed"
      return 1
    }

  if certutil -d sql:"${_dir}" -L 2>/dev/null | grep -qi "adorsys"; then
    info "Firefox profile: $(basename "${_dir}") ✔"
    FIREFOX_FOUND=1
  fi
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

# -----------------------------------------------------------------------------
# 6. Restart nudge
# -----------------------------------------------------------------------------
echo ""
info "============================================"
info "  AdORSYS Block-Page CA installed          "
info "============================================"
info ""
info "  System store  : ${DEST}"
info "  Browser NSS   : ${NSSDB}"
[ -n "${SNAP_CURRENT}" ] && info "  snap Chromium: $(basename "${SNAP_CURRENT}")"
[ "${FIREFOX_FOUND}" -eq 1 ] && info "  Firefox      : all profiles updated"
info ""
info "Restart browsers (Chrome, Edge, Firefox) to pick up the new root CA."
info "All Chromium-based browsers share the NSS store — restart Chrome once."
echo ""