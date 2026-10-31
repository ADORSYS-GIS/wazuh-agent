#!/usr/bin/env bats

setup() {
    export TEST_TMPDIR="$(mktemp -d)"
    export MOCK_BIN="$TEST_TMPDIR/bin"
    export SYSBIN="$TEST_TMPDIR/sysbin"
    mkdir -p "$MOCK_BIN" "$SYSBIN"

    # Link host standard utilities into sysbin (without curl/jq/apt/yum/apk/brew)
    for cmd in chmod mkdir date uname id mktemp rm touch env sh bash cat sed awk grep sleep head tail cp mv tr dirname wc sha256sum shasum cut sort echo printf which tee cmp [; do
        p="$(which "$cmd" 2>/dev/null || true)"
        [ -n "$p" ] && ln -s "$p" "$SYSBIN/$cmd"
    done

    # Default mock sudo executing command cleanly (stripping options like -E)
    cat << 'EOF' > "$MOCK_BIN/sudo"
#!/bin/sh
while [ $# -gt 0 ]; do
    case "$1" in
        -*) shift ;;
        *) break ;;
    esac
done
exec "$@"
EOF
    chmod +x "$MOCK_BIN/sudo"

    # Directory for generated mock scripts
    export MOCK_PAYLOADS="$TEST_TMPDIR/payloads"
    mkdir -p "$MOCK_PAYLOADS"
    echo '#!/bin/sh' > "$MOCK_PAYLOADS/setup-agent.sh"
    echo 'echo "mock setup-agent executed successfully"' >> "$MOCK_PAYLOADS/setup-agent.sh"
    chmod +x "$MOCK_PAYLOADS/setup-agent.sh"

    export ORIGINAL_PATH="$PATH"
    export PATH="$MOCK_BIN:$SYSBIN"
}

teardown() {
    export PATH="$ORIGINAL_PATH"
    rm -rf "$TEST_TMPDIR"
}

create_smart_curl() {
    cat << 'EOF' > "$MOCK_BIN/curl"
#!/bin/bash
target_out=""
url=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        -o)
            target_out="$2"
            shift 2
            ;;
        http*)
            url="$1"
            shift
            ;;
        *)
            shift
            ;;
    esac
done

if [[ "$MOCK_CURL_FAIL" == "1" ]]; then
    exit 1
fi

if [[ -n "$target_out" ]]; then
    if [[ "$url" == *"checksums.sha256"* ]]; then
        if [[ "$MOCK_CORRUPT_CHECKSUM" == "1" ]]; then
            echo "deadbeefdeadbeef  scripts/shared/utils.sh" > "$target_out"
            echo "deadbeefdeadbeef  scripts/linux/setup-agent.sh" >> "$target_out"
            echo "deadbeefdeadbeef  scripts/macos/setup-agent.sh" >> "$target_out"
        else
            for p in scripts/shared/utils.sh scripts/linux/deps.sh scripts/linux/install.sh scripts/linux/setup-docker.sh; do
                if [ -f "$p" ]; then
                    h=$(sha256sum "$p" | awk '{print $1}')
                    echo "$h  $p" >> "$target_out"
                fi
            done
            if [ -f "$MOCK_PAYLOADS/setup-agent.sh" ]; then
                h=$(sha256sum "$MOCK_PAYLOADS/setup-agent.sh" | awk '{print $1}')
                echo "$h  scripts/linux/setup-agent.sh" >> "$target_out"
                echo "$h  scripts/macos/setup-agent.sh" >> "$target_out"
            fi
        fi
        exit 0
    elif [[ "$url" == *"scripts/shared/utils.sh"* ]]; then
        cp scripts/shared/utils.sh "$target_out"
        exit 0
    elif [[ "$url" == *"setup-agent.sh"* ]]; then
        cp "$MOCK_PAYLOADS/setup-agent.sh" "$target_out"
        exit 0
    elif [[ "$url" == *"scripts/linux/deps.sh"* ]]; then
        cp scripts/linux/deps.sh "$target_out"
        exit 0
    elif [[ "$url" == *"scripts/linux/install.sh"* ]]; then
        echo '#!/bin/sh' > "$target_out"
        echo 'echo "mock linux install executed"' >> "$target_out"
        exit 0
    else
        echo "mock content" > "$target_out"
        exit 0
    fi
fi
exit 0
EOF
    chmod +x "$MOCK_BIN/curl"
}

# =============================================================================
# lib/verify.sh tests
# =============================================================================

@test "lib/verify.sh: validate_manager_address accepts valid domain and IPv4" {
    . lib/verify.sh
    run validate_manager_address "wazuh.internal.domain"
    [ "$status" -eq 0 ]

    run validate_manager_address "192.168.1.100"
    [ "$status" -eq 0 ]
}

@test "lib/verify.sh: validate_manager_address rejects empty and invalid address" {
    . lib/verify.sh
    run validate_manager_address ""
    [ "$status" -eq 1 ]
    [[ "$output" =~ "WAZUH_MANAGER is required" ]]

    run validate_manager_address "bad address with spaces"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "WAZUH_MANAGER has invalid format" ]]
}

@test "lib/verify.sh: validate_manager_address warns on default placeholder" {
    . lib/verify.sh
    run validate_manager_address "wazuh.example.com"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "default placeholder" ]]
}

@test "lib/verify.sh: validate_version accepts semantic versions" {
    . lib/verify.sh
    run validate_version "4.14.6-1"
    [ "$status" -eq 0 ]

    run validate_version "1.0.0"
    [ "$status" -eq 0 ]

    run validate_version "invalid-version"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Invalid version format" ]]

    run validate_version ""
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Version is required" ]]
}

@test "lib/verify.sh: validate_input validates required field and pattern" {
    . lib/verify.sh
    run validate_input "PORT" ""
    [ "$status" -eq 1 ]
    [[ "$output" =~ "PORT is required" ]]

    run validate_input "PORT" "1514" "^[0-9]+$"
    [ "$status" -eq 0 ]

    run validate_input "PORT" "abc" "^[0-9]+$"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "PORT has invalid format" ]]
}

@test "lib/verify.sh: verify_checksum checks matching and mismatching sha256" {
    . lib/verify.sh
    SAMPLE_FILE="$TEST_TMPDIR/sample.txt"
    echo "test content" > "$SAMPLE_FILE"
    HASH=$(sha256sum "$SAMPLE_FILE" | awk '{print $1}')

    run verify_checksum "$SAMPLE_FILE" "$HASH"
    [ "$status" -eq 0 ]

    run verify_checksum "$SAMPLE_FILE" "0000000000000000000000000000000000000000000000000000000000000000"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Checksum verification failed" ]]

    run verify_checksum "$TEST_TMPDIR/nonexistent.txt" "$HASH"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "File not found" ]]
}

# =============================================================================
# scripts/shared/utils.sh tests
# =============================================================================

@test "scripts/shared/utils.sh: logging and command_exists helpers work" {
    . scripts/shared/utils.sh
    run info_message "Test Info"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "[INFO]" ]]
    [[ "$output" =~ "Test Info" ]]

    run warn_message "Test Warn"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "[WARNING]" ]]

    run error_message "Test Error"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "[ERROR]" ]]

    run success_message "Test Success"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "[SUCCESS]" ]]

    run print_step 1 "Initializing"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "1: Initializing" ]]

    run command_exists "sh"
    [ "$status" -eq 0 ]

    run command_exists "nonexistent_binary_xyz"
    [ "$status" -eq 1 ]
}

@test "scripts/shared/utils.sh: maybe_sudo executes command" {
    . scripts/shared/utils.sh
    run maybe_sudo echo "running privileged"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "running privileged" ]]
}

@test "scripts/shared/utils.sh: calculate_sha256 and verify_checksum work" {
    . scripts/shared/utils.sh
    TARGET="$TEST_TMPDIR/test_sha.txt"
    echo "checksum verification target" > "$TARGET"
    EXPECTED=$(sha256sum "$TARGET" | awk '{print $1}')

    run calculate_sha256 "$TARGET"
    [ "$status" -eq 0 ]
    [ "$output" = "$EXPECTED" ]

    run verify_checksum "$TARGET" "$EXPECTED"
    [ "$status" -eq 0 ]

    run verify_checksum "$TARGET" "badhash123"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Checksum verification FAILED" ]]
}

@test "scripts/shared/utils.sh: sed_inplace performs in-place replacement" {
    . scripts/shared/utils.sh
    FILE="$TEST_TMPDIR/replace.txt"
    echo "foo = bar" > "$FILE"

    run sed_inplace 's/bar/baz/' "$FILE"
    [ "$status" -eq 0 ]
    [ "$(cat "$FILE")" = "foo = baz" ]
}

@test "scripts/shared/utils.sh: download_file with retry logic" {
    . scripts/shared/utils.sh
    create_smart_curl
    DEST="$TEST_TMPDIR/downloaded.txt"

    run download_file "https://example.com/file.txt" "$DEST" "test download" 2
    [ "$status" -eq 0 ]
    [[ "$output" =~ "downloaded successfully" ]]
}

# =============================================================================
# install.sh tests
# =============================================================================

@test "install.sh: full bootstrap installer succeeds when checksums match" {
    create_smart_curl
    export WAZUH_MANAGER="manager.example.org"
    export SKIP_VERIFY="false"

    run bash install.sh
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Wazuh Agent Bootstrap Installer" ]]
    [[ "$output" =~ "Checksum verified successfully" ]]
    [[ "$output" =~ "Executing setup-agent.sh" ]]
}

@test "install.sh: fails when checksum verification fails" {
    create_smart_curl
    export MOCK_CORRUPT_CHECKSUM="1"
    export WAZUH_MANAGER="manager.example.org"

    run bash install.sh
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Checksum verification FAILED" ]]
    [[ "$output" =~ "Aborting installation" ]]
}

@test "install.sh: bypasses verification when SKIP_VERIFY=true" {
    create_smart_curl
    export MOCK_CORRUPT_CHECKSUM="1"
    export SKIP_VERIFY="true"

    run bash install.sh
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Skipping verification (SKIP_VERIFY=true)" ]]
}

@test "install.sh: warns when WAZUH_MANAGER is missing" {
    create_smart_curl
    export WAZUH_MANAGER=""
    export SKIP_VERIFY="true"

    run bash install.sh
    [ "$status" -eq 0 ]
    [[ "$output" =~ "WAZUH_MANAGER is not set" ]]
}

# =============================================================================
# scripts/setup-agent.sh tests
# =============================================================================

@test "scripts/setup-agent.sh: downloads and verifies remote script" {
    create_smart_curl
    run bash scripts/setup-agent.sh
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Downloading checksums" ]]
    [[ "$output" =~ "Downloading script" ]]
}

@test "scripts/setup-agent.sh: aborts on checksum mismatch" {
    create_smart_curl
    export MOCK_CORRUPT_CHECKSUM="1"
    run bash scripts/setup-agent.sh
    [ "$status" -eq 4 ]
    [[ "$output" =~ "Checksum mismatch" ]]
}

# =============================================================================
# scripts/linux/deps.sh tests
# =============================================================================

@test "scripts/linux/deps.sh: detects Debian/Ubuntu when apt-get is available" {
    create_smart_curl
    cat << 'EOF' > "$MOCK_BIN/apt-get"
#!/bin/sh
echo "mock apt-get: $*"
exit 0
EOF
    chmod +x "$MOCK_BIN/apt-get"

    run bash scripts/linux/deps.sh
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Detected Debian/Ubuntu-based system" ]]
    [[ "$output" =~ "mock apt-get: update" ]]
    [[ "$output" =~ "Dependencies installed successfully" ]]
}

@test "scripts/linux/deps.sh: detects Red Hat/CentOS when yum is available" {
    create_smart_curl
    cat << 'EOF' > "$MOCK_BIN/yum"
#!/bin/sh
echo "mock yum: $*"
exit 0
EOF
    chmod +x "$MOCK_BIN/yum"

    run bash scripts/linux/deps.sh
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Detected Red Hat/CentOS-based system" ]]
    [[ "$output" =~ "mock yum: install" ]]
    [[ "$output" =~ "Dependencies installed successfully" ]]
}

@test "scripts/linux/deps.sh: detects Alpine when apk is available" {
    create_smart_curl
    cat << 'EOF' > "$MOCK_BIN/apk"
#!/bin/sh
echo "mock apk: $*"
exit 0
EOF
    chmod +x "$MOCK_BIN/apk"

    run bash scripts/linux/deps.sh
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Detected Alpine Linux system" ]]
    [[ "$output" =~ "mock apk: add" ]]
    [[ "$output" =~ "Dependencies installed successfully" ]]
}

@test "scripts/linux/deps.sh: fails on checksum error" {
    create_smart_curl
    export MOCK_CORRUPT_CHECKSUM="1"
    run bash scripts/linux/deps.sh
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Checksum verification failed for utils.sh" ]]
}

# =============================================================================
# scripts/linux/setup-agent.sh tests
# =============================================================================

@test "scripts/linux/setup-agent.sh: -h prints help message" {
    create_smart_curl
    run bash scripts/linux/setup-agent.sh -h
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Display this help message and exit" ]]
    [[ "$output" =~ "EXAMPLES" ]]
}

@test "scripts/linux/setup-agent.sh: rejects invalid Suricata mode" {
    create_smart_curl
    run bash scripts/linux/setup-agent.sh -s invalidmode
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Invalid mode for Suricata" ]]
}

@test "scripts/linux/setup-agent.sh: rejects both Suricata and Snort options" {
    create_smart_curl
    run bash scripts/linux/setup-agent.sh -s ids -n
    [ "$status" -eq 1 ]
    [[ "$output" =~ "You cannot install both Suricata (-s) and Snort (-n)" ]]
}

@test "scripts/linux/setup-agent.sh: handles invalid CLI options" {
    create_smart_curl
    run bash scripts/linux/setup-agent.sh -z
    [ "$status" -ne 0 ]
    [[ "$output" =~ "Invalid option" ]]
}

@test "scripts/linux/setup-agent.sh: accepts -t for Trivy and -b for NetBird" {
    create_smart_curl
    run bash scripts/linux/setup-agent.sh -s ids -t -b -h
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Display this help message and exit" ]]
}

@test "scripts/linux/setup-agent.sh: accepts -s ips mode" {
    create_smart_curl
    run bash scripts/linux/setup-agent.sh -s ips -h
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Display this help message and exit" ]]
}

create_mock_installation_env() {
    export OSSEC_PATH="$TEST_TMPDIR/ossec"
    export AR_BIN_DIR="$TEST_TMPDIR/ar_bin"
    mkdir -p "$OSSEC_PATH" "$AR_BIN_DIR"

    cat << 'EOF' > "$MOCK_BIN/sha256sum"
#!/bin/sh
echo "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad  $1"
EOF
    chmod +x "$MOCK_BIN/sha256sum"

    cat << 'EOF' > "$MOCK_BIN/getent"
#!/bin/sh
exit 0
EOF
    chmod +x "$MOCK_BIN/getent"

    cat << 'EOF' > "$MOCK_BIN/groupadd"
#!/bin/sh
exit 0
EOF
    chmod +x "$MOCK_BIN/groupadd"

    cat << 'EOF' > "$MOCK_BIN/chown"
#!/bin/sh
exit 0
EOF
    chmod +x "$MOCK_BIN/chown"

    cat << 'EOF' > "$MOCK_BIN/curl"
#!/bin/bash
target_out=""
url=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        -o)
            target_out="$2"
            shift 2
            ;;
        http*)
            url="$1"
            shift
            ;;
        *)
            shift
            ;;
    esac
done

if [[ -n "$target_out" ]]; then
    if [[ "$url" == *"checksums.sha256"* ]]; then
        cat << 'CHKSUM' > "$target_out"
ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad  scripts/shared/utils.sh
ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad  scripts/linux/deps.sh
ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad  scripts/linux/install.sh
ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad  scripts/linux/setup-agent.sh
ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad  scripts/linux/setup-docker.sh
ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad  files/active-response/linux/disable-usb-storage.sh
ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad  files/active-response/linux/alert-usb-hid.sh
ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad  scripts/linux/ca-install.sh
ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad  scripts/linux/uninstall.sh
ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad  version.txt
CHKSUM
        exit 0
    elif [[ "$url" == *"scripts/shared/utils.sh"* ]]; then
        cp scripts/shared/utils.sh "$target_out"
        exit 0
    elif [[ "$url" == *"version.txt"* ]]; then
        echo "4.14.6" > "$target_out"
        exit 0
    else
        echo '#!/bin/sh' > "$target_out"
        echo 'exit 0' >> "$target_out"
        chmod +x "$target_out"
        exit 0
    fi
else
    echo '#!/bin/sh'
    echo 'exit 0'
    exit 0
fi
EOF
    chmod +x "$MOCK_BIN/curl"
}

@test "scripts/linux/setup-agent.sh: runs full setup workflow with Suricata, Trivy, and NetBird" {
    create_mock_installation_env
    cat << 'EOF' > "$MOCK_BIN/snort"
#!/bin/sh
exit 0
EOF
    chmod +x "$MOCK_BIN/snort"

    run bash scripts/linux/setup-agent.sh -s ids -t -b
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Wazuh setup has been completed successfully" ]]
}

@test "scripts/linux/setup-agent.sh: runs full setup workflow with Snort" {
    create_mock_installation_env
    cat << 'EOF' > "$MOCK_BIN/suricata"
#!/bin/sh
exit 0
EOF
    chmod +x "$MOCK_BIN/suricata"

    run bash scripts/linux/setup-agent.sh -n
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Wazuh setup has been completed successfully" ]]
}

# =============================================================================
# scripts/linux/uninstall.sh tests
# =============================================================================

@test "scripts/linux/uninstall.sh: runs complete Linux uninstallation workflow" {
    create_smart_curl
    export OSSEC_PATH="$TEST_TMPDIR/var/ossec"
    export OSSEC_CONTROL_PATH="$TEST_TMPDIR/var/ossec/bin/wazuh-control"
    export REPO_FILE="$TEST_TMPDIR/wazuh.list"
    export GPG_KEY_FILE="$TEST_TMPDIR/wazuh.gpg"
    mkdir -p "$OSSEC_PATH"
    touch "$REPO_FILE" "$GPG_KEY_FILE"

    cat << 'EOF' > "$MOCK_BIN/systemctl"
#!/bin/sh
exit 0
EOF
    cat << 'EOF' > "$MOCK_BIN/dpkg"
#!/bin/sh
exit 0
EOF
    cat << 'EOF' > "$MOCK_BIN/apt"
#!/bin/sh
exit 0
EOF
    cat << 'EOF' > "$MOCK_BIN/ps"
#!/bin/sh
exit 1
EOF
    chmod +x "$MOCK_BIN/systemctl" "$MOCK_BIN/dpkg" "$MOCK_BIN/apt" "$MOCK_BIN/ps"

    run bash scripts/linux/uninstall.sh
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Wazuh agent uninstallation completed successfully" ]]
}

@test "scripts/linux/uninstall.sh: exits cleanly when no Wazuh components are detected" {
    create_smart_curl
    export OSSEC_PATH="$TEST_TMPDIR/nonexistent_wazuh"
    export OSSEC_CONTROL_PATH="$TEST_TMPDIR/nonexistent_wazuh/bin/wazuh-control"
    export REPO_FILE="$TEST_TMPDIR/wazuh.list"
    export GPG_KEY_FILE="$TEST_TMPDIR/wazuh.gpg"

    cat << 'EOF' > "$MOCK_BIN/dpkg"
#!/bin/sh
exit 1
EOF
    cat << 'EOF' > "$MOCK_BIN/ps"
#!/bin/sh
exit 1
EOF
    chmod +x "$MOCK_BIN/dpkg" "$MOCK_BIN/ps"

    run bash scripts/linux/uninstall.sh
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Wazuh agent does not exist, skipping" ]]
}

# =============================================================================
# Additional verify.sh & utils.sh helpers tests
# =============================================================================

@test "lib/verify.sh: fetch_remote_checksum retrieves hash from remote checksums" {
    . lib/verify.sh
    cat << 'EOF' > "$MOCK_BIN/curl"
#!/bin/sh
echo "112233445566  target.sh"
EOF
    chmod +x "$MOCK_BIN/curl"
    run fetch_remote_checksum "https://example.com/checksums.sha256" "target.sh"
    [ "$status" -eq 0 ]
    [ "$output" = "112233445566" ]
}

@test "lib/verify.sh: check_connectivity tests reachability via ping, nc, or curl" {
    . lib/verify.sh
    cat << 'EOF' > "$MOCK_BIN/ping"
#!/bin/sh
exit 0
EOF
    chmod +x "$MOCK_BIN/ping"
    run check_connectivity "wazuh.server"
    [ "$status" -eq 0 ]

    cat << 'EOF' > "$MOCK_BIN/ping"
#!/bin/sh
exit 1
EOF
    chmod +x "$MOCK_BIN/ping"
    cat << 'EOF' > "$MOCK_BIN/nc"
#!/bin/sh
exit 0
EOF
    chmod +x "$MOCK_BIN/nc"
    run check_connectivity "wazuh.server"
    [ "$status" -eq 0 ]

    cat << 'EOF' > "$MOCK_BIN/nc"
#!/bin/sh
exit 1
EOF
    chmod +x "$MOCK_BIN/nc"
    cat << 'EOF' > "$MOCK_BIN/curl"
#!/bin/sh
exit 1
EOF
    chmod +x "$MOCK_BIN/curl"
    run check_connectivity "unreachable.server"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Cannot verify connectivity" ]]
}

@test "lib/verify.sh: download_and_verify downloads and checks file" {
    create_smart_curl
    . lib/verify.sh
    DEST="$TEST_TMPDIR/downloaded_test.sh"
    HASH=$(printf "mock content\n" | sha256sum | awk '{print $1}')
    run download_and_verify "https://example.com/test.sh" "$DEST" "$HASH"
    [ "$status" -eq 0 ]
}

@test "scripts/shared/utils.sh: get_functional_python finds python binary" {
    . scripts/shared/utils.sh
    cat << 'EOF' > "$MOCK_BIN/python3"
#!/bin/sh
exit 0
EOF
    chmod +x "$MOCK_BIN/python3"
    run get_functional_python
    [ "$status" -eq 0 ]
    [ "$output" = "python3" ]
}

@test "scripts/shared/utils.sh: download_and_verify_file verifies pattern in checksum file" {
    create_smart_curl
    . scripts/shared/utils.sh
    DEST="$TEST_TMPDIR/verified_file.sh"
    CHECKSUM_FILE="$TEST_TMPDIR/checksums.txt"
    HASH=$(printf "mock content\n" | sha256sum | awk '{print $1}')
    echo "$HASH  target.sh" > "$CHECKSUM_FILE"

    run download_and_verify_file "https://example.com/target.sh" "$DEST" "target.sh" "target" "" "$CHECKSUM_FILE"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "checksum verification passed" ]]
}

@test "scripts/shared/utils.sh: download_and_verify_file fails on missing checksum pattern" {
    create_smart_curl
    . scripts/shared/utils.sh
    DEST="$TEST_TMPDIR/verified_file2.sh"
    CHECKSUM_FILE="$TEST_TMPDIR/checksums2.txt"
    echo "deadbeef  other.sh" > "$CHECKSUM_FILE"

    run download_and_verify_file "https://example.com/target.sh" "$DEST" "missing.sh" "target" "" "$CHECKSUM_FILE"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "No checksum found for target" ]]
}

@test "scripts/shared/utils.sh: configure_enrollment_group adds enrollment block after </server>" {
    . scripts/shared/utils.sh
    CONF="$TEST_TMPDIR/ossec.conf"
    cat > "$CONF" << 'XML'
<ossec_config>
  <client>
    <server>
      <address>wazuh.example.com</address>
    </server>
  </client>
</ossec_config>
XML

    run configure_enrollment_group "$CONF" "default,macos"
    [ "$status" -eq 0 ]
    grep -q "<groups>default,macos</groups>" "$CONF"
    # wazuh-cert-oauth2 anchors its certificate paths on <agent_name>
    grep -q "<agent_name></agent_name>" "$CONF"
    [ "$(grep -c '<enrollment>' "$CONF")" -eq 1 ]
    # enrollment must come after the server block
    [ "$(grep -n '</server>' "$CONF" | cut -d: -f1)" -lt "$(grep -n '<enrollment>' "$CONF" | cut -d: -f1)" ]
}

@test "scripts/shared/utils.sh: configure_enrollment_group replaces groups in existing enrollment block" {
    . scripts/shared/utils.sh
    CONF="$TEST_TMPDIR/ossec.conf"
    cat > "$CONF" << 'XML'
<ossec_config>
  <client>
    <server>
      <address>wazuh.example.com</address>
    </server>
    <enrollment>
      <agent_name></agent_name>
      <groups>default</groups>
      <agent_certificate_path>etc/sslagent.cert</agent_certificate_path>
    </enrollment>
  </client>
</ossec_config>
XML

    run configure_enrollment_group "$CONF" "default,linux"
    [ "$status" -eq 0 ]
    [ "$(grep -c '<groups>' "$CONF")" -eq 1 ]
    grep -q "<groups>default,linux</groups>" "$CONF"
    grep -q "<agent_certificate_path>etc/sslagent.cert</agent_certificate_path>" "$CONF"
    [ "$(grep -c '<enrollment>' "$CONF")" -eq 1 ]
}

@test "scripts/shared/utils.sh: configure_enrollment_group is idempotent" {
    . scripts/shared/utils.sh
    CONF="$TEST_TMPDIR/ossec.conf"
    printf '<ossec_config>\n  <client>\n    <server>\n    </server>\n  </client>\n</ossec_config>\n' > "$CONF"

    configure_enrollment_group "$CONF" "default,macos"
    cp "$CONF" "$TEST_TMPDIR/first.conf"
    run configure_enrollment_group "$CONF" "default,macos"
    [ "$status" -eq 0 ]
    cmp -s "$CONF" "$TEST_TMPDIR/first.conf"
}

@test "scripts/shared/utils.sh: configure_enrollment_group fails when ossec.conf has no server block" {
    . scripts/shared/utils.sh
    CONF="$TEST_TMPDIR/ossec.conf"
    printf '<ossec_config>\n</ossec_config>\n' > "$CONF"
    cp "$CONF" "$TEST_TMPDIR/orig.conf"

    run configure_enrollment_group "$CONF" "default,macos"
    [ "$status" -ne 0 ]
    cmp -s "$CONF" "$TEST_TMPDIR/orig.conf"
}

@test "scripts/shared/utils.sh: enable_sca_remote_commands sets option once" {
    . scripts/shared/utils.sh
    OPTS="$TEST_TMPDIR/local_internal_options.conf"
    printf '# local options\nsca.remote_commands=0\nlogcollector.remote_commands=0\n' > "$OPTS"

    run enable_sca_remote_commands "$OPTS"
    [ "$status" -eq 0 ]
    run enable_sca_remote_commands "$OPTS"
    [ "$status" -eq 0 ]
    [ "$(grep -c '^sca.remote_commands=' "$OPTS")" -eq 1 ]
    grep -q '^sca.remote_commands=1$' "$OPTS"
    grep -q '^logcollector.remote_commands=0$' "$OPTS"
}

@test "scripts/shared/utils.sh: enable_sca_remote_commands creates missing file" {
    . scripts/shared/utils.sh
    OPTS="$TEST_TMPDIR/new_local_internal_options.conf"

    run enable_sca_remote_commands "$OPTS"
    [ "$status" -eq 0 ]
    [ "$(cat "$OPTS")" = "sca.remote_commands=1" ]
}
