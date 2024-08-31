#!/usr/bin/env bats

bash /app/scripts/deps.sh

chmod +x /app/scripts/install.sh

# Test if the script runs without errors
@test "script runs without errors" {
  export WAZUH_AGENT_NAME="test-agent-123"
  export WAZUH_MANAGER="10.0.0.2"
  run /app/scripts/install.sh
  [ "$status" -eq 0 ]
}

