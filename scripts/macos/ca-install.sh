#!/usr/bin/env bash
# =============================================================================
# Company Root CA — macOS device installer (Safari)
#
# Installs the Company Root CA (CN=root-ca, O=Company) into the macOS system
# keychain (the trust store used by Safari and other system TLS consumers),
# and REMOVES any retired block-page root CA it finds there.
#
# Safety model:
#   * The expected SHA-256 fingerprint is PINNED below. The script refuses to
#     install anything that does not match it (fail-closed).
#   * The keychain is verified AFTER install — the fingerprint of what actually
#     landed in the store must match the pin.
#   * Retired CAs (old AdORSYS block-page root, previous company roots) are
#     removed by FINGERPRINT/SUBJECT (via their SHA-1 hash), not by label, so
#     they are always cleaned up even if installed under a different name.
#   * Idempotent: re-running is a no-op when the pinned CA is already present.
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
#   ./macos-ca-install.sh --check [path/to/ca.crt]  # validate only, no install
#
# Environment variables:
#   CA_BRANCH  — Git branch to fetch the cert from (default: main).
#                NOTE: when running via sudo, set it AFTER sudo so it is
#                passed through:  sudo CA_BRANCH=<branch> ./macos-ca-install.sh
#                (or: export CA_BRANCH=<branch> && sudo -E ./macos-ca-install.sh)
#   CA_CRT     — Path to a local .crt file (skips fetch if set)
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

# Retired block-page root CAs — removed from the keychain, by fingerprint.
RETIRED_SHA256=(
  "43623b8212aaedd1045317b7a17257f11082b36969e1d78ceeff76f3cfcc3885"  # AdORSYS Block Page Root CA
)
# Retired subjects (substring match, lowercase) — belt & braces for CAs whose
# fingerprint is not in the list above.
RETIRED_SUBJECTS=(
  "adorsys block page root ca"
)

info()  { echo -e "\033[1;32m[INFO]\033[0m  $*"; }
warn()  { echo -e "\033[1;33m[WARN]\033[0m  $*" >&2; }
die()   { echo -e "\033[1;31m[ERROR]\033[0m $*" >&2; exit 1; }

# --- Fetch and source shared helpers -------------------------------------------
CA_BRANCH="${CA_BRANCH:-main}"
GITHUB_RAW_URL="https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent"
CERT_PATH_IN_REPO="scripts/shared/company-root-ca.crt"
HELPERS_PATH_IN_REPO="scripts/shared/ca-helpers.sh"

trap 'rm -f "${CERT_TMPFILE:-}" "${HELPERS_TMPFILE:-}"' EXIT

if ! command -v curl >/dev/null 2>&1; then
  die "curl is required but not installed. Please install curl and retry."
fi

# Fetch the helper script
HELPERS_TMPFILE=$(mktemp /tmp/ca-helpers.XXXXXX.sh)
CERT_TMPFILE=$(mktemp /tmp/company-root-ca.XXXXXX.crt)

FETCH_HELPERS_URL="${GITHUB_RAW_URL}/${CA_BRANCH}/${HELPERS_PATH_IN_REPO}"
HTTP_CODE=$(curl -sS -w "%{http_code}" -o "${HELPERS_TMPFILE}" "${FETCH_HELPERS_URL}" 2>/dev/null) || true
if [[ "${HTTP_CODE}" != "200" ]] ; then
  die "Failed to fetch CA helpers (HTTP ${HTTP_CODE}). Check branch '${CA_BRANCH}' and try again."
fi
source "${HELPERS_TMPFILE}"

# -----------------------------------------------------------------------------
# 0. Real user (works via sudo) + keychain paths
# -----------------------------------------------------------------------------
REAL_USER=$(logname 2>/dev/null || echo "${SUDO_USER:-${USER:-}}")
REAL_USER_HOME=$(dscl . -read "/Users/${REAL_USER}" NFSHomeDirectory 2>/dev/null | cut -d: -f2 || true)
REAL_USER_HOME="${REAL_USER_HOME:-${HOME}}"

KEYCHAIN="/Library/Keychains/System.keychain"

# --- Input: mode + CA certificate --------------------------------------------
MODE="install"
CA_FILE=""
if [[ "${1:-}" = "--check" ]] ||  [[ "${1:-}" = "-c" ]] ; then
  MODE="check"
  CA_FILE="${2:-}"
elif [[ "${1:-}" = "--help" ]] ||  [[ "${1:-}" = "-h" ]] ; then
  sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
fi

if [[ -n "${CA_FILE}" ]] ||  [[ -n "${CA_CRT:-}" ]] ; then
  CA_FILE="${CA_FILE:-${CA_CRT}}"
  info "Using local certificate file: ${CA_FILE}"
  case "${CA_FILE}" in
    /*) ;;
    *) CA_FILE="${REAL_USER_HOME}/${CA_FILE}" ;;
  esac
else
  FETCH_URL="${GITHUB_RAW_URL}/${CA_BRANCH}/${CERT_PATH_IN_REPO}"
  info "Fetching certificate from GitHub (branch: ${CA_BRANCH})..."
  info "URL: ${FETCH_URL}"
  HTTP_CODE=$(curl -sS -w "%{http_code}" -o "${CERT_TMPFILE}" "${FETCH_URL}" 2>/dev/null) || true
  if [[ "${HTTP_CODE}" != "200" ]] ; then
    die "Failed to fetch certificate (HTTP ${HTTP_CODE}). Check branch '${CA_BRANCH}' and try again."
  fi
  CA_FILE="${CERT_TMPFILE}"
fi

check_cert "${CA_FILE}"

if [[ "${MODE}" = "check" ]] ; then
  info "OK — ${CA_FILE} is the pinned Company Root CA (${EXPECTED_CN})"
  exit 0
fi

# -----------------------------------------------------------------------------
# Keychain scan: remove retired CAs (by SHA-1 hash), detect the pinned CA.
# Sets PINNED_FOUND=1 when a cert matching the pinned SHA-256 is in the store.
# -----------------------------------------------------------------------------
PINNED_FOUND=0
keychain_scan() {
  PINNED_FOUND=0
  local sha1="" pem="" fp="" subj="" line="" in_pem=0
  while IFS= read -r line; do
    case "${line}" in
      "SHA-1 hash:"*) sha1="${line#SHA-1 hash: }" ;;
      "-----BEGIN CERTIFICATE-----"*) pem="${line}"$'\n'; in_pem=1 ;;
      "-----END CERTIFICATE-----"*)
        pem="${pem}${line}"$'\n'
        fp=$(printf '%s' "${pem}" | openssl x509 -noout -fingerprint -sha256 2>/dev/null | norm_fp || true)
        subj=$(printf '%s' "${pem}" | openssl x509 -noout -subject 2>/dev/null \
          | sed 's/^subject=//' | tr -d ' ' | tr '[:upper:]' '[:lower:]' || true)
        if [[ "${fp}" = "${EXPECTED_SHA256}" ]] ; then PINNED_FOUND=1; fi
        if is_retired_fp "${fp}" || is_retired_subject "${subj}"; then
          warn "Removing retired CA from keychain (SHA-1 ${sha1})"
          security delete-certificate -Z "${sha1}" "${KEYCHAIN}" >/dev/null 2>&1 \
            || warn "Failed to delete ${sha1} — is the keychain locked?"
        fi
        pem=""
        in_pem=0
        ;;
      *) [[ "${in_pem}" = "1" ]] &&  pem="${pem}${line}"$'\n' ;;
    esac
  done < <(security find-certificate -a -Z -p "${KEYCHAIN}" 2>/dev/null)
}

# -----------------------------------------------------------------------------
# Install into the macOS system keychain
#
# check_cert above already pinned the source file's SHA-256 fingerprint.
# Here we install it and then confirm the fingerprint that actually landed in
# the keychain matches that same pin.
#
# macOS applies system trust settings asynchronously via trustd, so
# add-trusted-cert can fail transiently right after import touches the
# keychain. The real `security` error is printed (not suppressed) and the
# trust write is retried, since a re-run otherwise appears to "work" only
# because the daemon finished in the background.
# -----------------------------------------------------------------------------
# -----------------------------------------------------------------------------
# Trust-write helper
#
# `security add-trusted-cert -d` ALWAYS requires macOS's SecurityAgent to show
# an authorization dialog to the logged-in user — even when the script already
# runs as root. When this script is a child of a root process (e.g. the GUI
# installer app relaunched via `osascript ... with administrator privileges`),
# it has no access to the user's GUI session, so SecurityAgent cannot display
# the dialog and fails with:
#   SecTrustSettingsSetTrustSettings: ... no user interaction was possible.
#
# Fix: run the trust command in the logged-in console user's GUI session via
# `launchctl asuser`, so the system can show its password dialog on screen.
# If that is unavailable (SSH, login window, non-admin console user), fall back
# to a direct root invocation.
# -----------------------------------------------------------------------------
NO_INTERACTION_RE='no user interaction was possible|user interaction is not allowed|User interaction is not allowed'

trust_cert() {
  local cert_file="$1" err=""

  if err=$(security add-trusted-cert -d -r trustRoot -k "${KEYCHAIN}" "${cert_file}" 2>&1); then
    return 0
  fi

  if echo "${err}" | grep -Eqi "${NO_INTERACTION_RE}"; then
    warn "Direct trust write had no GUI session — retrying in the console user's session..."
    local console_uid=""
    console_uid=$(stat -f %u /dev/console 2>/dev/null || echo "")
    if [ -n "${console_uid}" ] && [ "${console_uid}" != "0" ]; then
      if err=$(launchctl asuser "${console_uid}" sudo -u "#${console_uid}" \
                 security add-trusted-cert -d -r trustRoot -k "${KEYCHAIN}" "${cert_file}" 2>&1); then
        return 0
      fi
    fi
  fi

  echo "${err}" >&2
  return 1
}

info "Installing into system keychain (${KEYCHAIN})..."

keychain_scan

if [[ "${PINNED_FOUND}" -eq 1 ]] ; then
  info "Company Root CA already present in system keychain ✔"
else
  if ! security import "${CA_FILE}" -k "${KEYCHAIN}" -t cert >/dev/null 2>&1; then
    die "Failed to import certificate into system keychain. Run with sudo."
  fi

  trusted=0
  trusted=0
  last_err=""
  for attempt in 1 2 3; do
    if last_err=$(trust_cert "${CA_FILE}"); then
      trusted=1
      break
    fi
    warn "add-trusted-cert failed (attempt ${attempt}/3): ${last_err}"
    # "no user interaction" is a hard failure (no GUI session for the dialog);
    # retrying cannot fix it — bail out now with actionable guidance.
    if echo "${last_err}" | grep -Eqi "${NO_INTERACTION_RE}"; then
      die "Cannot set trust: macOS could not show the confirmation dialog.
       This happens when the script runs without access to the user's screen
       (e.g. over SSH or from a background/root process).
       Fix: run  sudo bash ca-install.sh  from Terminal.app, or deploy the CA
       as an MDM configuration profile."
    fi
    sleep 2
  done

  if [[ "${trusted}" -ne 1 ]] ; then
    case "${last_err}" in
      *"not permitted"*|*"not authorized"*|*"User interaction is not allowed"*)
        die "Failed to mark certificate as trusted — permission denied. Run with sudo." ;;
    esac
    die "Failed to mark certificate as trusted after 3 attempts."
  fi

  info "Certificate imported and marked as trusted root. ✔"
fi

# -----------------------------------------------------------------------------
# Verify AFTER install — by fingerprint, matching the pin checked earlier
# -----------------------------------------------------------------------------
keychain_scan

if [[ "${PINNED_FOUND}" -eq 1 ]] ; then
  info "Verified in system keychain (fingerprint match) ✔"
else
  die "Verification failed: pinned CA not found in system keychain"
fi

info "Company Root CA installed successfully ✔"