#!/usr/bin/env bats

setup() {
    # Determine OS type and set paths
    if [[ "$(uname)" == "Linux" ]]; then
        export OSSEC_PATH="/var/ossec/etc"
        export ACTIVE_RESPONSE_PATH="/var/ossec/active-response/bin"
        export YARA_RULES_PATH="/var/ossec/ruleset/yara/rules"
    elif [[ "$(uname)" == "Darwin" ]]; then
        export OSSEC_PATH="/Library/Ossec/etc"
        export ACTIVE_RESPONSE_PATH="/Library/Ossec/active-response/bin"
        export YARA_RULES_PATH="/Library/Ossec/ruleset/yara/rules"
    else
        echo "Unsupported OS"
        exit 1
    fi
    
    # Check if we have root privileges
    export HAS_ROOT=false
    if [ "$(id -u)" -eq 0 ]; then
        HAS_ROOT=true
    elif sudo -n true 2>/dev/null; then
        HAS_ROOT=true
    fi
}

# Helper function to run commands with appropriate privileges
run_privileged() {
    if [ "$HAS_ROOT" = true ]; then
        if [ "$(id -u)" -eq 0 ]; then
            run "$@"
        else
            run sudo "$@"
        fi
    else
        skip "This test requires root privileges"
    fi
}

# --- Wazuh Configuration File ---
@test "Wazuh configuration file exists" {
    run_privileged test -f "${OSSEC_PATH}/ossec.conf"
    [ "$status" -eq 0 ]
}

# --- YARA Script and Rules ---
@test "YARA script exists" {
    run_privileged test -f "${ACTIVE_RESPONSE_PATH}/yara.sh"
    [ "$status" -eq 0 ]
}

@test "YARA script has correct permissions" {
    if [ "$HAS_ROOT" = false ]; then
        skip "Root privileges required for permission check"
    fi
    
    if [[ "$(uname)" == "Linux" ]]; then
        run stat -c "%U %G %a" "${ACTIVE_RESPONSE_PATH}/yara.sh"
    else
        # macOS version
        run stat -f "%Su %Sg %A" "${ACTIVE_RESPONSE_PATH}/yara.sh"
    fi
    
    [ "$status" -eq 0 ]
    [[ "$output" == "root wazuh 750" ]]
}

@test "YARA rules file exists" {
    run_privileged test -f "${YARA_RULES_PATH}/yara_rules.yar"
    [ "$status" -eq 0 ]
}

@test "YARA rules directory has correct permissions" {
    if [ "$HAS_ROOT" = false ]; then
        skip "Root privileges required for permission check"
    fi
    
    if [[ "$(uname)" == "Linux" ]]; then
        run stat -c "%U %G" "${YARA_RULES_PATH}"
    else
        # macOS version
        run stat -f "%Su %Sg" "${YARA_RULES_PATH}"
    fi
    
    [ "$status" -eq 0 ]
    [[ "$output" == "root wazuh" ]]
}

# --- Notification Tools (Linux only) ---
@test "notify-send is installed (Linux only)" {
    if [[ "$(uname)" != "Linux" ]]; then
        skip "This test only runs on Linux"
    fi
    run which notify-send
    [ "$status" -eq 0 ]
}

@test "notify-send version matches expected (Linux only)" {
    if [[ "$(uname)" != "Linux" ]]; then
        skip "This test only runs on Linux"
    fi
    run notify-send --version
    [ "$status" -eq 0 ]
    [[ "$output" =~ "0.8.3" ]]
}

@test "zenity is installed (Linux only)" {
    if [[ "$(uname)" != "Linux" ]]; then
        skip "This test only runs on Linux"
    fi
    run which zenity
    [ "$status" -eq 0 ]
}

# --- Wazuh Agent Status ---
@test "Wazuh agent is running" {
    if [[ "$(uname)" == "Linux" ]]; then
        run systemctl is-active wazuh-agent
    else
        run /Library/Ossec/bin/wazuh-control status
    fi
    [ "$status" -eq 0 ]
}

# --- Suricata/Snort Installation (if selected) ---
@test "IDS engine is installed" {
    # This test would need to be adjusted based on which IDS was selected
    if [[ -n "$IDS_ENGINE" ]]; then
        case "$IDS_ENGINE" in
            "suricata")
                run which suricata
                [ "$status" -eq 0 ]
                ;;
            "snort")
                run which snort
                [ "$status" -eq 0 ]
                ;;
        esac
    else
        skip "No IDS engine selected"
    fi
}

# --- Trivy Installation (if selected) ---
@test "Trivy is installed (if selected)" {
    if [[ "$INSTALL_TRIVY" == "TRUE" ]]; then
        run which trivy
        [ "$status" -eq 0 ]
    else
        skip "Trivy not selected for installation"
    fi
}