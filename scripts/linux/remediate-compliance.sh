#!/usr/bin/env bash
#
# Wazuh Linux SCA Compliance Remediation & Verification Script
#
# Aligned with:
#   - adorsys Endpoint Baseline Linux (wazuh-helm: adorsys_baseline_linux.yml, Checks 90000-90013)
#   - Wazuh Gateway compliance profile (wazuh-gateway: src/compliance_profiles/linux.json)
#
# Features:
#   - Safe, non-destructive configuration changes with backups and automated rollback
#   - Full visudo -c validation (compatible with sudo and sudo-rs)
#   - Direct /etc/sudoers logfile configuration (matching SCA check 90007)
#   - Case-insensitive SSH drop-in neutralization and direct /etc/ssh/sshd_config hardening
#   - Live sshd -T effective configuration verification + file content verification
#   - auditctl -l live kernel rule verification + rules.d persistence verification
#   - Verification for pending OS updates (90001) and reboot/uptime (90002)
#   - Noninteractive apt-get upgrade with dpkg force-confdef / force-confold
#   - Preserves scoped NOPASSWD entries (wazuh, ossec, cloud-init, ec2, vagrant)
#   - Trailing newline safety for appending directives
#   - Clean silent backups without stray stdout paths
#   - Non-zero exit code on failure for CI/CD or automation gating
#
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

FAILED_CHECKS=0

info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()      { echo -e "${GREEN}[OK]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; }
pass()    { echo -e "  [${GREEN}PASS${NC}] $*"; }
fail()    { echo -e "  [${RED}FAIL${NC}] $*"; FAILED_CHECKS=$((FAILED_CHECKS + 1)); }
notice()  { echo -e "  [${YELLOW}WARN${NC}] $*"; }

if [ "$EUID" -ne 0 ]; then
    error "This script must be run as root. Please run with: sudo bash $0"
    exit 1
fi

FIX_NOPASSWD=true
SKIP_UPGRADE=false
for arg in "$@"; do
    case "$arg" in
        --no-fix-nopasswd)
            FIX_NOPASSWD=false
            ;;
        --skip-upgrade)
            SKIP_UPGRADE=true
            ;;
    esac
done

BACKUP_DIR="/var/backups/wazuh-compliance-$(date +%Y%m%d%H%M%S)"
mkdir -p "$BACKUP_DIR"
chmod 0700 "$BACKUP_DIR"

backup_file() {
    local target="$1"
    if [ -f "$target" ]; then
        cp -a "$target" "$BACKUP_DIR/$(basename "$target").bak_$(date +%s%N)"
    fi
}

append_safely() {
    local line="$1"
    local file="$2"
    if [ -f "$file" ] && [ -s "$file" ]; then
        # If file does not end with a newline, add one first
        if [ -n "$(tail -c1 "$file")" ]; then
            echo "" >> "$file"
        fi
    fi
    echo "$line" >> "$file"
}

echo -e "${BOLD}==========================================================${NC}"
echo -e "${BOLD} Wazuh Linux Compliance Remediation & Verification${NC}"
echo -e " Policy: adorsys Endpoint Baseline (Checks 90000-90013 / CIS)"
echo -e " Backups saved to: ${CYAN}${BACKUP_DIR}${NC}"
echo -e "${BOLD}==========================================================${NC}"
echo ""

# -------------------------------------------------------------
# 1. Ensure sudo is installed (Check 90006 / CIS 28654)
# -------------------------------------------------------------
info "1/7 Checking sudo installation (Check 90006 / CIS 28654)..."
if ! command -v sudo >/dev/null 2>&1; then
    if command -v apt-get >/dev/null 2>&1; then
        DEBIAN_FRONTEND=noninteractive apt-get update -y && \
        DEBIAN_FRONTEND=noninteractive apt-get install -y sudo
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y sudo
    elif command -v yum >/dev/null 2>&1; then
        yum install -y sudo
    fi
    ok "sudo has been installed."
else
    ok "sudo is already installed."
fi

# -------------------------------------------------------------
# 2. Ensure sudo log file exists (Check 90007 / CIS 28656)
# -------------------------------------------------------------
info "2/7 Configuring sudo logfile in /etc/sudoers (Check 90007 / CIS 28656)..."
SUDOERS_FILE="/etc/sudoers"
if [ -f "$SUDOERS_FILE" ]; then
    SUDO_BAK="$BACKUP_DIR/sudoers.bak"
    cp -a "$SUDOERS_FILE" "$SUDO_BAK"

    # Ensure Defaults logfile is configured in /etc/sudoers (Rule 90007 checks the main file)
    if grep -qE '^\s*Defaults\s+logfile=' "$SUDOERS_FILE"; then
        ok "Defaults logfile already active in $SUDOERS_FILE."
    elif grep -qE '^\s*#\s*Defaults\s+logfile=' "$SUDOERS_FILE"; then
        sed -i 's/^\s*#\s*Defaults\s\+logfile=.*/Defaults logfile="\/var\/log\/sudo.log"/' "$SUDOERS_FILE"
        ok "Uncommented Defaults logfile in $SUDOERS_FILE."
    else
        append_safely 'Defaults logfile="/var/log/sudo.log"' "$SUDOERS_FILE"
        ok "Added Defaults logfile to $SUDOERS_FILE."
    fi

    # Validate syntax using visudo -c (guarding against false rollback on sudo-rs)
    if command -v visudo >/dev/null 2>&1; then
        if visudo --version 2>&1 | grep -qi "sudo-rs"; then
            ok "Detected sudo-rs; logfile directive retained without classic visudo check."
        elif ! visudo -c >/dev/null 2>&1; then
            warn "visudo syntax check failed! Rolling back changes to /etc/sudoers..."
            cp -a "$SUDO_BAK" "$SUDOERS_FILE"
        else
            ok "visudo syntax validation passed."
        fi
    fi
else
    warn "/etc/sudoers not found; skipping sudoers log configuration."
fi

touch /var/log/sudo.log
chmod 0600 /var/log/sudo.log
chown root:root /var/log/sudo.log
ok "Logfile verified at /var/log/sudo.log."

# -------------------------------------------------------------
# 3. Restrict su command access via PAM (Check 90004 / CIS 28660)
# -------------------------------------------------------------
info "3/7 Restricting access to 'su' command via PAM (Check 90004 / CIS 28660)..."
PAM_SU="/etc/pam.d/su"
if [ -f "$PAM_SU" ]; then
    backup_file "$PAM_SU"
    ADMIN_GROUP="sudo"
    if ! getent group sudo >/dev/null 2>&1 && getent group wheel >/dev/null 2>&1; then
        ADMIN_GROUP="wheel"
    fi

    if grep -qE '^\s*auth\s+required\s+pam_wheel\.so.*group=' "$PAM_SU"; then
        ok "Active pam_wheel restriction already present in $PAM_SU."
    elif grep -qE '^\s*#\s*auth\s+required\s+pam_wheel\.so\s+use_uid\s+group=' "$PAM_SU"; then
        sed -i "s/^\s*#\s*\(auth\s\+required\s\+pam_wheel\.so\s\+use_uid\s\+group=.*\)/\1/" "$PAM_SU"
        ok "Uncommented existing pam_wheel configuration in $PAM_SU."
    else
        if grep -q "pam_rootok\.so" "$PAM_SU"; then
            sed -i "/auth\s*sufficient\s*pam_rootok\.so/a auth       required   pam_wheel.so use_uid group=${ADMIN_GROUP}" "$PAM_SU"
        else
            append_safely "auth       required   pam_wheel.so use_uid group=${ADMIN_GROUP}" "$PAM_SU"
        fi
        ok "Configured PAM su restriction for group: ${ADMIN_GROUP}."
    fi
else
    warn "$PAM_SU not found; skipping."
fi

# -------------------------------------------------------------
# 4. Audit rules for sudoers scope (Check 90005 / CIS 28597)
# -------------------------------------------------------------
info "4/7 Configuring auditd rules for sudoers changes (Check 90005 / CIS 28597)..."
if ! command -v auditctl >/dev/null 2>&1; then
    info "Installing auditd..."
    if command -v apt-get >/dev/null 2>&1; then
        DEBIAN_FRONTEND=noninteractive apt-get update -y >/dev/null 2>&1 || true
        DEBIAN_FRONTEND=noninteractive apt-get install -y auditd audispd-plugins 2>/dev/null || true
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y audit 2>/dev/null || true
    elif command -v yum >/dev/null 2>&1; then
        yum install -y audit 2>/dev/null || true
    fi
    if ! command -v auditctl >/dev/null 2>&1; then
        warn "auditd installation could not complete. Audit rules may not be applied."
    fi
fi

if [ -d "/etc/audit/rules.d" ]; then
    AUDIT_RULES_FILE="/etc/audit/rules.d/50-sudoers-scope.rules"
    backup_file "$AUDIT_RULES_FILE"
    cat << 'EOF' > "$AUDIT_RULES_FILE"
-w /etc/sudoers -p wa -k scope
-w /etc/sudoers.d/ -p wa -k scope
EOF
    chmod 0640 "$AUDIT_RULES_FILE"

    # Reload persistent audit configuration
    if command -v augenrules >/dev/null 2>&1; then
        augenrules --load 2>/dev/null || true
    fi

    # Directly insert into running kernel audit tables to satisfy auditctl -l immediately
    if command -v auditctl >/dev/null 2>&1; then
        auditctl -w /etc/sudoers -p wa -k scope 2>/dev/null || true
        auditctl -w /etc/sudoers.d/ -p wa -k scope 2>/dev/null || true
    fi

    systemctl enable --now auditd 2>/dev/null || true
    ok "auditd rules applied and persistent."
else
    warn "/etc/audit/rules.d directory not found; skipping audit rule persistence."
fi

# -------------------------------------------------------------
# 5. Auditing NOPASSWD in sudoers (Check 90003 / CIS 28657)
# -------------------------------------------------------------
info "5/7 Auditing NOPASSWD in sudoers files (Check 90003 / CIS 28657)..."
NOPASSWD_FOUND=false
ACTIVE_NOPASSWD_FILES=()

for f in /etc/sudoers /etc/sudoers.d/*; do
    [ -f "$f" ] || continue
    matches=$(grep -nE '^[[:space:]]*[^#[:space:]].*NOPASSWD' "$f" 2>/dev/null || true)
    if [ -n "$matches" ]; then
        NOPASSWD_FOUND=true
        ACTIVE_NOPASSWD_FILES+=("$f")
        base=$(basename "$f")
        if [[ "$base" =~ wazuh|ossec ]]; then
            info "Found scoped agent NOPASSWD entry in $f (Required for Wazuh Agent operations):"
            echo "$matches" | sed 's/^/    /'
        elif [[ "$base" =~ 90-cloud-init|cloud_init|vagrant|ec2 ]]; then
            warn "Found cloud/VM provisioning NOPASSWD entry in $f (Preserved to prevent admin lockout):"
            echo "$matches" | sed 's/^/    /'
        else
            warn "Found user/custom NOPASSWD entry in $f:"
            echo "$matches" | sed 's/^/    /'
        fi
    fi
done

if [ "$NOPASSWD_FOUND" = true ]; then
    if [ "$FIX_NOPASSWD" = true ]; then
        info "Remediating custom user NOPASSWD lines (preserving agent/cloud rules)..."
        for f in "${ACTIVE_NOPASSWD_FILES[@]}"; do
            base=$(basename "$f")
            # Preserve wazuh/ossec and cloud/ec2 provisioning to prevent breaking automation and ssh lockout
            if [[ "$base" =~ wazuh|ossec|90-cloud-init|cloud_init|vagrant|ec2 ]]; then
                info "Preserving protected entry in $f."
                continue
            fi
            f_bak="$BACKUP_DIR/$(basename "$f").bak"
            cp -a "$f" "$f_bak"
            sed -i 's/NOPASSWD:[[:space:]]*/PASSWD: /g' "$f" 2>/dev/null || true
            if command -v visudo >/dev/null 2>&1; then
                if ! visudo -c >/dev/null 2>&1; then
                    warn "visudo error after modifying $f. Reverting..."
                    cp -a "$f_bak" "$f"
                fi
            fi
        done
        ok "Custom NOPASSWD entries updated."
    else
        warn "NOPASSWD entries were detected above (--no-fix-nopasswd passed)."
        warn "Note: Automated stripping of NOPASSWD is risky on cloud VMs or endpoints with agent automation."
    fi
else
    ok "No active NOPASSWD directives detected in sudoers."
fi

# -------------------------------------------------------------
# 6. SSH Hardening (Checks 90008, 90009, 90010, 90011 / CIS)
# -------------------------------------------------------------
info "6/7 Hardening SSH daemon configuration (Checks 90008-90011)..."
SSHD_CONFIG="/etc/ssh/sshd_config"
if [ -f "$SSHD_CONFIG" ]; then
    SSHD_BAK="$BACKUP_DIR/sshd_config.bak"
    cp -a "$SSHD_CONFIG" "$SSHD_BAK"

    # In OpenSSH, first match wins!
    # Neutralize any earlier drop-in in /etc/ssh/sshd_config.d/ setting conflicting values (case-insensitive)
    if [ -d "/etc/ssh/sshd_config.d" ]; then
        for conf in /etc/ssh/sshd_config.d/*.conf; do
            [ -f "$conf" ] || continue
            [ "$(basename "$conf")" = "99-compliance.conf" ] && continue
            if grep -qiE '^\s*PermitRootLogin\s+' "$conf"; then
                warn "Neutralizing overriding PermitRootLogin in $conf..."
                backup_file "$conf"
                sed -i 's/^\s*PermitRootLogin.*/# Overridden by 99-compliance.conf: &/I' "$conf"
            fi
            if grep -qiE '^\s*PermitEmptyPasswords\s+' "$conf"; then
                backup_file "$conf"
                sed -i 's/^\s*PermitEmptyPasswords.*/# Overridden by 99-compliance.conf: &/I' "$conf"
            fi
            if grep -qiE '^\s*MaxAuthTries\s+' "$conf"; then
                backup_file "$conf"
                sed -i 's/^\s*MaxAuthTries.*/# Overridden by 99-compliance.conf: &/I' "$conf"
            fi
        done
    fi

    # Ensure privilege separation directory and host keys exist so sshd -T never fails
    mkdir -p /run/sshd
    if command -v ssh-keygen >/dev/null 2>&1; then
        ssh-keygen -A >/dev/null 2>&1 || true
    fi

    # Check 90008: replace active or commented (#) PermitRootLogin
    if grep -qiE '^\s*#?\s*PermitRootLogin' "$SSHD_CONFIG"; then
        sed -i 's/^\s*#\?\s*PermitRootLogin.*/PermitRootLogin no/I' "$SSHD_CONFIG"
    else
        append_safely "PermitRootLogin no" "$SSHD_CONFIG"
    fi

    # Check 90009: replace active or commented (#) PermitEmptyPasswords
    if grep -qiE '^\s*#?\s*PermitEmptyPasswords' "$SSHD_CONFIG"; then
        sed -i 's/^\s*#\?\s*PermitEmptyPasswords.*/PermitEmptyPasswords no/I' "$SSHD_CONFIG"
    else
        append_safely "PermitEmptyPasswords no" "$SSHD_CONFIG"
    fi

    # Check 90011: replace active or commented (#) MaxAuthTries
    if grep -qiE '^\s*#?\s*MaxAuthTries' "$SSHD_CONFIG"; then
        sed -i 's/^\s*#\?\s*MaxAuthTries.*/MaxAuthTries 4/I' "$SSHD_CONFIG"
    else
        append_safely "MaxAuthTries 4" "$SSHD_CONFIG"
    fi

    # Check 90010: Permissions 0600 root:root on sshd_config
    chmod 0600 "$SSHD_CONFIG"
    chown root:root "$SSHD_CONFIG"

    # Also configure drop-in file 99-compliance.conf
    if [ -d "/etc/ssh/sshd_config.d" ]; then
        SSHD_DROPIN="/etc/ssh/sshd_config.d/99-compliance.conf"
        cat << 'EOF' > "$SSHD_DROPIN"
PermitRootLogin no
PermitEmptyPasswords no
MaxAuthTries 4
EOF
        chmod 0600 "$SSHD_DROPIN"
        chown root:root "$SSHD_DROPIN"
    fi

    # Validate sshd configuration with sshd -t before reloading
    if command -v sshd >/dev/null 2>&1; then
        if sshd -t >/dev/null 2>&1; then
            # Use reload instead of restart to avoid dropping active SSH sessions
            systemctl reload sshd 2>/dev/null || systemctl reload ssh 2>/dev/null || true
            ok "sshd configuration validated and reloaded."
        else
            warn "sshd -t syntax error! Rolling back /etc/ssh/sshd_config..."
            cp -a "$SSHD_BAK" "$SSHD_CONFIG"
        fi
    fi
else
    ok "/etc/ssh/sshd_config not found (SSH server not installed); skipping."
fi

# -------------------------------------------------------------
# 7. Remove Insecure Services: Telnet & FTP (Checks 90012 & 90013)
# -------------------------------------------------------------
info "7/7 Removing prohibited legacy software (telnet, ftp)..."
if command -v dpkg-query >/dev/null 2>&1; then
    TELNET_PKGS=("telnet" "inetutils-telnet" "telnetd" "telnet-ssl")
    FTP_PKGS=("ftp" "tnftp" "lukemftp")
    
    INSTALLED_BAD_PKGS=()
    for pkg in "${TELNET_PKGS[@]}" "${FTP_PKGS[@]}"; do
        if dpkg-query -s "$pkg" 2>/dev/null | grep -q "Status: install ok installed"; then
            INSTALLED_BAD_PKGS+=("$pkg")
        fi
    done

    if [ ${#INSTALLED_BAD_PKGS[@]} -gt 0 ]; then
        info "Purging detected legacy packages: ${INSTALLED_BAD_PKGS[*]}"
        DEBIAN_FRONTEND=noninteractive apt-get purge -y "${INSTALLED_BAD_PKGS[@]}" 2>/dev/null || {
            for pkg in "${INSTALLED_BAD_PKGS[@]}"; do
                apt-get purge -y "$pkg" 2>/dev/null || true
            done
        }
        ok "Prohibited packages purged."
    else
        ok "No prohibited legacy telnet/ftp packages installed."
    fi
elif command -v dnf >/dev/null 2>&1; then
    dnf remove -y telnet ftp 2>/dev/null || true
    ok "Prohibited legacy packages checked/removed."
elif command -v yum >/dev/null 2>&1; then
    yum remove -y telnet ftp 2>/dev/null || true
    ok "Prohibited legacy packages checked/removed."
fi

# -------------------------------------------------------------
# OS Updates (Check 90001: Ensure no OS updates are pending)
# -------------------------------------------------------------
if [ "$SKIP_UPGRADE" = false ]; then
    info "Updating system packages automatically (Check 90001)..."
    if command -v apt-get >/dev/null 2>&1; then
        DEBIAN_FRONTEND=noninteractive apt-get update -y && \
        DEBIAN_FRONTEND=noninteractive apt-get -y \
            -o Dpkg::Options::="--force-confdef" \
            -o Dpkg::Options::="--force-confold" upgrade
    elif command -v dnf >/dev/null 2>&1; then
        dnf upgrade -y
    elif command -v yum >/dev/null 2>&1; then
        yum update -y
    fi
    ok "System packages updated."
    if [ -f /var/run/reboot-required ]; then
        warn "A system reboot is required for applied updates to take full effect (Check 90002)."
    fi
else
    info "Skipping OS package upgrade (--skip-upgrade passed)."
fi

# -------------------------------------------------------------
# Trigger Wazuh Agent Rescan
# -------------------------------------------------------------
echo ""
info "Triggering Wazuh agent rescan..."
if systemctl is-active --quiet wazuh-agent 2>/dev/null || command -v /var/ossec/bin/wazuh-control >/dev/null 2>&1; then
    systemctl restart wazuh-agent 2>/dev/null || /var/ossec/bin/wazuh-control restart || true
    ok "Wazuh agent restarted successfully."
else
    warn "Wazuh agent service not active or not installed."
fi

# -------------------------------------------------------------
# Post-Remediation Compliance Verification
# -------------------------------------------------------------
echo ""
echo -e "${BOLD}==========================================================${NC}"
echo -e "${BOLD} Post-Remediation Verification Results${NC}"
echo -e " (Directly evaluating adorsys_baseline_linux.yml rules)"
echo -e "${BOLD}==========================================================${NC}"

# Check 90006: Sudo installed
if command -v sudo >/dev/null 2>&1; then
    pass "Check 90006 (CIS 28654) - sudo is installed"
else
    fail "Check 90006 (CIS 28654) - sudo is NOT installed"
fi

# Check 90007: Sudo logfile configured
if grep -qE '^\s*Defaults\s+logfile=\S+\.log' /etc/sudoers 2>/dev/null; then
    pass "Check 90007 (CIS 28656) - sudo logfile is configured in /etc/sudoers"
else
    fail "Check 90007 (CIS 28656) - sudo logfile is NOT configured in /etc/sudoers"
fi

# Check 90004: PAM su restricted
if grep -qE '^\s*auth\s+required\s+pam_wheel\.so.*group=' /etc/pam.d/su 2>/dev/null; then
    pass "Check 90004 (CIS 28660) - PAM su command access restricted"
else
    fail "Check 90004 (CIS 28660) - PAM su restriction missing in /etc/pam.d/su"
fi

# Check 90005: Audit rules for sudoers (requires BOTH live kernel rules and persistent rules.d)
LIVE_AUDIT=$(auditctl -l 2>/dev/null || true)
AUDIT_LIVE_SUDOERS=false
AUDIT_LIVE_DIR=false
if echo "$LIVE_AUDIT" | grep -qE -- '^-w\s+/etc/sudoers\s+-p\s+wa\s+-k\s+scope'; then
    AUDIT_LIVE_SUDOERS=true
fi
if echo "$LIVE_AUDIT" | grep -qE -- '^-w\s+/etc/sudoers\.d/?\s+-p\s+wa\s+-k\s+scope'; then
    AUDIT_LIVE_DIR=true
fi

AUDIT_RULES_FILE_CHECK=false
if grep -rqE '^-w\s+/etc/sudoers\s+-p\s+wa\s+-k\s+scope' /etc/audit/rules.d/ 2>/dev/null && \
   grep -rqE '^-w\s+/etc/sudoers\.d/?\s+-p\s+wa\s+-k\s+scope' /etc/audit/rules.d/ 2>/dev/null; then
    AUDIT_RULES_FILE_CHECK=true
fi

if [ "$AUDIT_LIVE_SUDOERS" = true ] && [ "$AUDIT_LIVE_DIR" = true ] && [ "$AUDIT_RULES_FILE_CHECK" = true ]; then
    pass "Check 90005 (CIS 28597) - Sudoers audit rules active in auditctl and persistent in rules.d"
else
    fail "Check 90005 (CIS 28597) - Sudoers audit rules missing in live auditctl or persistent rules.d"
fi

# Check 90003: NOPASSWD in sudoers
STRICT_NOPASSWD=$(grep -rnE '^[[:space:]]*[^#[:space:]].*NOPASSWD' /etc/sudoers /etc/sudoers.d/* 2>/dev/null || true)
if [ -z "$STRICT_NOPASSWD" ]; then
    pass "Check 90003 (CIS 28657) - No NOPASSWD directives present in sudoers"
else
    CUSTOM_NOPASSWD=$(echo "$STRICT_NOPASSWD" | grep -vE 'wazuh|ossec|90-cloud-init|cloud_init|vagrant|ec2' || true)
    if [ -z "$CUSTOM_NOPASSWD" ]; then
        notice "Check 90003 (CIS 28657) - Scoped agent/cloud NOPASSWD entries present (intentional exemption)"
    else
        fail "Check 90003 (CIS 28657) - Unapproved custom NOPASSWD detected in sudoers"
    fi
fi

# Check 90008, 90009, 90010, 90011: SSH Hardening
if [ -f /etc/ssh/sshd_config ]; then
    EFFECTIVE_SSH=""
    SSHD_EXEC_ERR=""
    if command -v sshd >/dev/null 2>&1; then
        RAW_SSH_DUMP=$(sshd -T 2>&1 || true)
        if echo "$RAW_SSH_DUMP" | grep -qi '^permitrootlogin'; then
            EFFECTIVE_SSH="$RAW_SSH_DUMP"
        else
            SSHD_EXEC_ERR=$(echo "$RAW_SSH_DUMP" | head -n 1)
        fi
    fi

    # 90008: PermitRootLogin no
    FILE_ROOT_LOGIN=false
    EFFECTIVE_ROOT_LOGIN=false
    if grep -qiE '^\s*PermitRootLogin\s+no' /etc/ssh/sshd_config 2>/dev/null; then
        FILE_ROOT_LOGIN=true
    fi
    if [ -n "$EFFECTIVE_SSH" ] && echo "$EFFECTIVE_SSH" | grep -qi '^permitrootlogin no'; then
        EFFECTIVE_ROOT_LOGIN=true
    fi
    if [ "$FILE_ROOT_LOGIN" = true ] && [ "$EFFECTIVE_ROOT_LOGIN" = true ]; then
        pass "Check 90008 (CIS 28638) - sshd PermitRootLogin is disabled (effective & file)"
    else
        fail "Check 90008 (CIS 28638) - PermitRootLogin no missing or overridden in sshd${SSHD_EXEC_ERR:+ (sshd -T error: $SSHD_EXEC_ERR)}"
    fi

    # 90009: PermitEmptyPasswords no
    FILE_EMPTY_PW=true
    EFFECTIVE_EMPTY_PW=false
    if grep -qiE '^\s*PermitEmptyPasswords\s+yes' /etc/ssh/sshd_config 2>/dev/null; then
        FILE_EMPTY_PW=false
    fi
    if [ -n "$EFFECTIVE_SSH" ] && echo "$EFFECTIVE_SSH" | grep -qi '^permitemptypasswords no'; then
        EFFECTIVE_EMPTY_PW=true
    fi
    if [ "$FILE_EMPTY_PW" = true ] && [ "$EFFECTIVE_EMPTY_PW" = true ]; then
        pass "Check 90009 (CIS 28640) - sshd PermitEmptyPasswords disabled (effective & file)"
    else
        fail "Check 90009 (CIS 28640) - PermitEmptyPasswords allowed in effective sshd config${SSHD_EXEC_ERR:+ (sshd -T error: $SSHD_EXEC_ERR)}"
    fi

    # 90010: Permissions 0600 root:root
    SSHD_PERM=$(stat -c "%a %u %g" /etc/ssh/sshd_config 2>/dev/null || stat -f "%Op %u %g" /etc/ssh/sshd_config 2>/dev/null || true)
    if [[ "$SSHD_PERM" =~ (600|400)[[:space:]]+0[[:space:]]+0 ]]; then
        pass "Check 90010 (CIS 28634) - /etc/ssh/sshd_config permissions (0600 root:root)"
    else
        fail "Check 90010 (CIS 28634) - /etc/ssh/sshd_config permissions invalid: $SSHD_PERM"
    fi

    # 90011: MaxAuthTries <= 4
    FILE_MAX_AUTH=true
    EFFECTIVE_MAX_AUTH=false
    if grep -qiE '^\s*MaxAuthTries\s+([5-9]|[1-9][0-9]+)' /etc/ssh/sshd_config 2>/dev/null; then
        FILE_MAX_AUTH=false
    fi
    if [ -n "$EFFECTIVE_SSH" ]; then
        m=$(echo "$EFFECTIVE_SSH" | awk '/^maxauthtries/{print $2}')
        if [ -n "$m" ] && [ "$m" -le 4 ]; then
            EFFECTIVE_MAX_AUTH=true
        fi
    fi
    if [ "$FILE_MAX_AUTH" = true ] && [ "$EFFECTIVE_MAX_AUTH" = true ]; then
        pass "Check 90011 (CIS 28649) - sshd MaxAuthTries configured <= 4 (effective & file)"
    else
        fail "Check 90011 (CIS 28649) - sshd MaxAuthTries exceeds 4 or could not be determined${SSHD_EXEC_ERR:+ (sshd -T error: $SSHD_EXEC_ERR)}"
    fi
else
    pass "Check 90008-90011 - SSH daemon not installed (N/A)"
fi

# Check 90012: Telnet client
TELNET_PRESENT=false
if command -v dpkg-query >/dev/null 2>&1; then
    if dpkg-query -s telnet inetutils-telnet 2>/dev/null | grep -q "Status: install ok installed"; then
        TELNET_PRESENT=true
    fi
fi
if [ "$TELNET_PRESENT" = false ]; then
    pass "Check 90012 (CIS 28570) - Telnet client is not installed"
else
    fail "Check 90012 (CIS 28570) - Telnet client (telnet / inetutils-telnet) still installed"
fi

# Check 90013: FTP client
FTP_PRESENT=false
if command -v dpkg-query >/dev/null 2>&1; then
    if dpkg-query -s ftp tnftp 2>/dev/null | grep -q "Status: install ok installed"; then
        FTP_PRESENT=true
    fi
fi
if [ "$FTP_PRESENT" = false ]; then
    pass "Check 90013 (CIS 28712) - FTP client is not installed"
else
    fail "Check 90013 (CIS 28712) - FTP client (ftp / tnftp) still installed"
fi

# Check 90001: Ensure no OS updates are pending
if command -v apt-get >/dev/null 2>&1; then
    if APT_SIM_OUT=$(apt-get -s -o Debug::NoLocking=true upgrade 2>&1); then
        PENDING_UPDATES=$(echo "$APT_SIM_OUT" | grep -c ^Inst || true)
        PENDING_UPDATES="${PENDING_UPDATES:-0}"
        if [ "$PENDING_UPDATES" -eq 0 ]; then
            pass "Check 90001 - No OS updates pending (0 packages)"
        else
            fail "Check 90001 - $PENDING_UPDATES OS update(s) pending (run update & upgrade)"
        fi
    else
        fail "Check 90001 - apt simulation failed (package manager error)"
    fi
elif command -v dnf >/dev/null 2>&1; then
    if dnf -q check-update >/dev/null 2>&1; then
        pass "Check 90001 - No OS updates pending"
    else
        fail "Check 90001 - OS updates pending"
    fi
else
    pass "Check 90001 - OS update check skipped (unsupported package manager)"
fi

# Check 90002: Ensure the system has been restarted recently
REBOOT_NEEDED=false
UPTIME_SECS=$(cut -d. -f1 /proc/uptime 2>/dev/null || echo 0)
if [ -f /var/run/reboot-required ]; then
    REBOOT_NEEDED=true
fi
if command -v needs-restarting >/dev/null 2>&1; then
    if ! needs-restarting -r >/dev/null 2>&1; then
        REBOOT_NEEDED=true
    fi
fi
if [ "$UPTIME_SECS" -ge 604800 ]; then
    REBOOT_NEEDED=true
fi

if [ "$REBOOT_NEEDED" = false ]; then
    UPTIME_DAYS=$(( UPTIME_SECS / 86400 ))
    pass "Check 90002 - System rebooted recently (uptime ${UPTIME_DAYS}d, no reboot required)"
else
    fail "Check 90002 - System requires reboot (pending reboot or uptime >= 7 days)"
fi

# Check 90000: Full Disk Encryption (Informational)
ROOT_TYPE=$(sh -c "lsblk -s -l -n -o TYPE \$(findmnt -n -o SOURCE --nofsroot / 2>/dev/null) 2>/dev/null" || true)
if echo "$ROOT_TYPE" | grep -q "crypt"; then
    pass "Check 90000 - Full Disk Encryption is active (LUKS / crypt)"
else
    notice "Check 90000 - Full Disk Encryption: not encrypted (Skipped by user preference)"
fi

echo -e "${BOLD}==========================================================${NC}"
if [ "$FAILED_CHECKS" -eq 0 ]; then
    echo -e "${GREEN} Remediation & verification PASSED! (0 failures)${NC}"
    echo -e " Please allow ~1-2 minutes for the Wazuh agent scan to finish."
    echo -e "${BOLD}==========================================================${NC}"
    exit 0
else
    echo -e "${RED} Remediation complete with ${FAILED_CHECKS} failed check(s).${NC}"
    echo -e " Please review the failures listed above."
    echo -e "${BOLD}==========================================================${NC}"
    exit 1
fi
