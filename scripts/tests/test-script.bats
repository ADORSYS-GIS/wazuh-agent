#!/usr/bin/env bats

WAZUH_MANAGER="10.0.0.2"

chmod +x /app/scripts/install.sh

# Test if the script runs without errors
@test "script runs without errors" {
  export WAZUH_AGENT_NAME="test-agent-123"
  /app/scripts/install.sh
  [ "$status" -eq 0 ]
}

