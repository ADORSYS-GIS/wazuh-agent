#!/usr/bin/env bash
# =============================================================================
# AdORSYS Block-Page CA — macOS device installer (Safari)
#
# Installs the AdORSYS Block Page Root CA into the macOS system keychain,
# which is the trust store used by Safari (and other system TLS consumers).
#
# Requirements:
#   - macOS
#   - sudo / admin user (for system keychain writes)
#   - curl (to fetch the certificate from GitHub)
#
# Usage:
#   sudo ./macos-ca-install.sh
#   sudo CA_BRANCH=dns-block ./macos-ca-install.sh
#   sudo ./macos-ca-install.sh /path/to/ca.crt   # override: local file
#
# Environment variables:
#   CA_BRANCH  — Git branch to fetch the cert from (default: main).
#                NOTE: when running via sudo, set it AFTER sudo so it is
#                passed through:  sudo CA_BRANCH=<branch> ./macos-ca-install.sh
#                (or: export CA_BRANCH=<branch> && sudo -E ./macos-ca-install.sh)
#   CA_CRT     — Path to a local .crt file (skips fetch if set)
# =============================================================================

set -euo pipefail

info()  { echo -e "\033[1;32m[INFO]\033[0m  $*"; }
warn()  { echo -e "\033[1;33m[WARN]\033[0m  $*" >&2; }
die()   { echo -e "\033[1;31m[ERROR]\033[0m $*" >&2; exit 1; }

# GitHub raw content base URL for the certificate
GITHUB_RAW_URL="https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent"
CERT_PATH_IN_REPO="scripts/block-dns/adorsys-block-page-ca.crt"

# -----------------------------------------------------------------------------
# 0. Real user (works via sudo) + keychain paths
# -----------------------------------------------------------------------------
REAL_USER=$(logname 2>/dev/null || echo "${SUDO_USER:-${USER:-}}")
REAL_USER_HOME=$(dscl . -read "/Users/${REAL_USER}" NFSHomeDirectory 2>/dev/null | cut -d: -f2)
REAL_USER_HOME="${REAL_USER_HOME:-${HOME}}"

KEYCHAIN="/Library/Keychains/System.keychain"
CERT_LABEL="AdORSYS Block Page Root CA"

# Temp file for the fetched certificate
CERT_TMPFILE=$(mktemp /tmp/adorsys-block-ca.XXXXXX.crt)
trap 'rm -f "${CERT_TMPFILE}"' EXIT

# -----------------------------------------------------------------------------
# 1. Obtain the CA certificate
# -----------------------------------------------------------------------------
CA_BRANCH="${CA_BRANCH:-main}"

if [ -n "${1:-}" ]; then
  # User provided a local file as argument
  CA_FILE="${1}"
  case "${CA_FILE}" in
    /*) ;;
    *) CA_FILE="${REAL_USER_HOME}/${CA_FILE}" ;;
  esac
elif [ -n "${CA_CRT:-}" ]; then
  # User provided a local file via env
  CA_FILE="${CA_CRT}"
  case "${CA_FILE}" in
    /*) ;;
    *) CA_FILE="${REAL_USER_HOME}/${CA_FILE}" ;;
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

  info "Certificate fetched successfully ✔"
  info "Stored temporarily at: ${CERT_TMPFILE}"

  # Use the tmp file as the source for the keychain import below
  CA_FILE="${CERT_TMPFILE}"
fi

[ -f "${CA_FILE}" ] || die "CA file not found: ${CA_FILE}"
[ -s "${CA_FILE}" ] || die "CA file is empty: ${CA_FILE}"

# -----------------------------------------------------------------------------
# 2. Validate it looks like a certificate
# -----------------------------------------------------------------------------
if ! grep -q 'BEGIN CERTIFICATE' "${CA_FILE}"; then
  die "File does not look like a certificate: ${CA_FILE}"
fi

CA_CN=$(openssl x509 -in "${CA_FILE}" -noout -subject 2>/dev/null \
  | tr -d ' ' | grep -o 'CN=[^,]*' | sed 's/CN=//')

info "CA subject : ${CA_CN}"
info "CA file    : ${CA_FILE}"

# -----------------------------------------------------------------------------
# 3. Install into the macOS system keychain
# -----------------------------------------------------------------------------
info "Installing into system keychain (${KEYCHAIN})..."

# Remove any previous copy of the same-named CA to avoid duplicate entries
security delete-certificate -c "${CERT_LABEL}" "${KEYCHAIN}" >/dev/null 2>&1 \
  || true

# Import the certificate into the system keychain
if ! security import "${CA_FILE}" -k "${KEYCHAIN}" -t cert >/dev/null 2>&1; then
  die "Failed to import certificate into system keychain. Run with sudo."
fi

# Set full server trust for the imported CA
if ! security add-trusted-cert -d \
  -r trustRoot \
  -k "${KEYCHAIN}" \
  "${CA_FILE}" >/dev/null 2>&1; then
  die "Failed to mark certificate as trusted. Run with sudo."
fi

info "Certificate imported and marked as trusted root. ✔"

# -----------------------------------------------------------------------------
# 4. Verify
# -----------------------------------------------------------------------------
if security find-certificate -c "${CERT_LABEL}" "${KEYCHAIN}" >/dev/null 2>&1; then
  info "Verified in system keychain: ${CERT_LABEL} ✔"
else
  warn "Could not verify certificate in system keychain."
fi

info "AdORSYS Block-Page CA installed successfully ✔"