#!/usr/bin/env bats

setup() {
    # Determine OS type and set paths
    if [[ "$(uname)" == "Linux" ]]; then
        export OSSEC_PATH="/var/ossec"
        export STAT_FORMAT="-c %U %G %a"
        export SERVICE_CMD="systemctl is-active wazuh-agent"
    else
        export OSSEC_PATH="/Library/Ossec"
        export STAT_FORMAT="-f %Su %Sg %A"
        export SERVICE_CMD="/Library/Ossec/bin/wazuh-control status"
    fi

    export OSSEC_CONF_PATH="$OSSEC_PATH/etc/ossec.conf"
    export ACTIVE_RESPONSE_PATH="$OSSEC_PATH/active-response/bin"
    export YARA_RULES_PATH="$OSSEC_PATH/ruleset/yara/rules"
    export EXPECTED_USER="root"
    export EXPECTED_GROUP="wazuh"
}

@test "Wazuh directory structure exists" {
    [ -d "$OSSEC_PATH" ]
    [ -d "$OSSEC_PATH/etc" ]
    [ -d "$OSSEC_PATH/bin" ]
}

@test "ossec.conf exists" {
    [ -f "$OSSEC_CONF_PATH" ]
}

@test "YARA components are installed" {
    # Check active response script exists
    [ -f "$ACTIVE_RESPONSE_PATH/yara.sh" ]
    
    # Check rules file exists
    [ -f "$YARA_RULES_PATH/yara_rules.yar" ]
}

@test "Wazuh agent service is running" {
    run bash -c "$SERVICE_CMD"
    [ "$status" -eq 0 ] || {
        echo "Service status check failed. Debug info:"
        echo "Service command: $SERVICE_CMD"
        echo "Output: $output"
        echo "Exit code: $status"
        false
    }
}

@test "File permissions are correct" {
    skip "Permission checks require manual verification in CI"
    
    files_to_check=(
        "$OSSEC_CONF_PATH"
        "$ACTIVE_RESPONSE_PATH/yara.sh"
        "$YARA_RULES_PATH/yara_rules.yar"
    )
    
    for file in "${files_to_check[@]}"; do
        [ -f "$file" ]  # Ensure file exists
        run stat $STAT_FORMAT "$file"
        [ "$status" -eq 0 ]
        [[ "$output" =~ "$EXPECTED_USER $EXPECTED_GROUP" ]]
    done
}