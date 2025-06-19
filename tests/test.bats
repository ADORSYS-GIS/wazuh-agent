#!/usr/bin/env bats

setup() {
    # Create temporary directory for test files
    export TEST_DIR=$(mktemp -d)
    export ORIGINAL_PATH=$PATH
    
    # Mock commands
    export MOCK_BIN="$TEST_DIR/mock_bin"
    mkdir -p "$MOCK_BIN"
    
    # Create mock binaries
    cat > "$MOCK_BIN/uname" <<EOF
#!/bin/sh
echo "Linux"
EOF
    chmod +x "$MOCK_BIN/uname"
    
    cat > "$MOCK_BIN/apt-get" <<EOF
#!/bin/sh
echo "apt-get \$@"
EOF
    chmod +x "$MOCK_BIN/apt-get"
    
    cat > "$MOCK_BIN/yum" <<EOF
#!/bin/sh
echo "yum \$@"
EOF
    chmod +x "$MOCK_BIN/yum"
    
    cat > "$MOCK_BIN/systemctl" <<EOF
#!/bin/sh
echo "systemctl \$@"
EOF
    chmod +x "$MOCK_BIN/systemctl"
    
    cat > "$MOCK_BIN/curl" <<EOF
#!/bin/sh
echo "curl \$@"
EOF
    chmod +x "$MOCK_BIN/curl"
    
    cat > "$MOCK_BIN/sed" <<EOF
#!/bin/sh
echo "sed \$@"
EOF
    chmod +x "$MOCK_BIN/sed"
    
    cat > "$MOCK_BIN/sudo" <<EOF
#!/bin/sh
echo "sudo \$@"
EOF
    chmod +x "$MOCK_BIN/sudo"
    
    cat > "$MOCK_BIN/mktemp" <<EOF
#!/bin/sh
echo "$TEST_DIR/tempfile"
EOF
    chmod +x "$MOCK_BIN/mktemp"
    
    # Add mock binaries to PATH
    export PATH="$MOCK_BIN:$PATH"
    
    # Source the script under test
    source "./scripts/install.sh"
}

teardown() {
    # Cleanup
    rm -rf "$TEST_DIR"
    export PATH=$ORIGINAL_PATH
}

@test "command_exists returns true for existing commands" {
    run command_exists "uname"
    [ "$status" -eq 0 ]
}

@test "command_exists returns false for non-existing commands" {
    run command_exists "nonexistentcommand"
    [ "$status" -eq 1 ]
}


@test "OS detection sets correct variables" {
    [ "$OS" = "Linux" ]
    [ "$PACKAGE_MANAGER" = "apt" ] || [ "$PACKAGE_MANAGER" = "yum" ] || [ "$PACKAGE_MANAGER" = "zypper" ]
}

@test "import_keys sets up repository for apt" {
    # Setup for apt
    export PACKAGE_MANAGER="apt"
    export REPO_FILE="$TEST_DIR/wazuh.list"
    export GPG_KEYRING="$TEST_DIR/wazuh.gpg"
    
    run import_keys
    [ "$status" -eq 0 ]
    [[ "$output" == *"GPG key and repository configured successfully"* ]]
}

@test "create_upgrade_script creates executable file" {
    export UPGRADE_SCRIPT_PATH="$TEST_DIR/adorsys-update.sh"
    
    run create_upgrade_script
    [ "$status" -eq 0 ]
    [ -f "$UPGRADE_SCRIPT_PATH" ]
    [[ "$output" == *"Script created at $UPGRADE_SCRIPT_PATH"* ]]
    
    # Verify script contains manager address
    run grep "WAZUH_MANAGER=\"$WAZUH_MANAGER\"" "$UPGRADE_SCRIPT_PATH"
    [ "$status" -eq 0 ]
}
