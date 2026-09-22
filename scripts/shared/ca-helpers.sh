#!/usr/bin/env bash

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
