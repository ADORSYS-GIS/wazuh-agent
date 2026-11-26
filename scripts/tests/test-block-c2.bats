#!/usr/bin/env bats
# Tests for files/active-response/linux/block-c2.sh. iptables is mocked; nothing touches the host firewall.

SCRIPT="$BATS_TEST_DIRNAME/../../files/active-response/linux/block-c2.sh"

setup() {
    export TEST_TMPDIR="$(mktemp -d)"
    export BLOCK_C2_LOG="$TEST_TMPDIR/ar.log"
    export BLOCK_C2_PROTECTED="192.0.2.53"   # stands in for the gateway / DNS server
    export BLOCK_C2_LOCAL="10.0.0.5"
    mkdir -p "$TEST_TMPDIR/bin"
    # Mock iptables: record every call; -D fails once nothing is left to delete.
    cat > "$TEST_TMPDIR/bin/iptables" <<'EOF'
#!/bin/sh
echo "iptables $*" >> "$TEST_TMPDIR/fw.log"
case "$1" in
  -D) n=$(cat "$TEST_TMPDIR/rules" 2>/dev/null || echo 0); [ "$n" -gt 0 ] || exit 1; echo $((n - 1)) > "$TEST_TMPDIR/rules" ;;
  -I) n=$(cat "$TEST_TMPDIR/rules" 2>/dev/null || echo 0); echo $((n + 1)) > "$TEST_TMPDIR/rules" ;;
esac
exit 0
EOF
    cp "$TEST_TMPDIR/bin/iptables" "$TEST_TMPDIR/bin/ip6tables"
    sed -i.bak 's/^echo "iptables/echo "ip6tables/' "$TEST_TMPDIR/bin/ip6tables"
    chmod +x "$TEST_TMPDIR/bin/iptables" "$TEST_TMPDIR/bin/ip6tables"
    export PATH="$TEST_TMPDIR/bin:$PATH"
}

teardown() {
    rm -rf "$TEST_TMPDIR"
}

alert() { # alert <command> <src_ip> <dest_ip>
    printf '{"version":1,"origin":{"name":"node01","module":"wazuh-execd"},"command":"%s","parameters":{"extra_args":[],"alert":{"rule":{"level":13,"id":"100013","description":"Suricata: malware"},"data":{"src_ip":"%s","dest_ip":"%s","alert":{"signature":"ET MALWARE test"}}},"program":"active-response/bin/block-c2.sh"}}\n' "$1" "$2" "$3"
}

pick() {
    BLOCK_C2_SOURCED=1 sh -c ". \"$SCRIPT\"; pick_target \"$1\" \"$2\""
}

@test "outbound C2: blocks the public destination, not this machine" {
    run pick 10.0.0.5 203.0.113.7
    [ "$output" = "203.0.113.7" ]
}

@test "inbound from a public host: blocks the source" {
    run pick 198.51.100.9 10.0.0.5
    [ "$output" = "198.51.100.9" ]
}

@test "private, CGNAT/NetBird, link-local and protected addresses are never chosen" {
    run pick 10.0.0.5 172.16.4.4;      [ -z "$output" ]
    run pick 10.0.0.5 100.120.48.146;  [ -z "$output" ]
    run pick 10.0.0.5 169.254.1.1;     [ -z "$output" ]
    run pick 10.0.0.5 192.0.2.53;      [ -z "$output" ]
    run pick 10.0.0.5 fd90:4fd2::1;    [ -z "$output" ]
    run pick 10.0.0.5 "not-an-ip";     [ -z "$output" ]
}

@test "IPv6 public destination is chosen" {
    run pick 10.0.0.5 2001:db8:abcd::10
    [ "$output" = "2001:db8:abcd::10" ]
}

@test "add: asks check_keys, blocks both directions on continue" {
    run sh -c "{ $(declare -f alert); alert add 10.0.0.5 203.0.113.7; echo '{\"command\":\"continue\"}'; } | sh \"$SCRIPT\""
    [ "$status" -eq 0 ]
    [[ "$output" == *'"command":"check_keys"'* ]]
    [[ "$output" == *'"keys":["203.0.113.7"]'* ]]
    grep -q -- "-I OUTPUT -d 203.0.113.7" "$TEST_TMPDIR/fw.log"
    grep -q -- "-I INPUT -s 203.0.113.7" "$TEST_TMPDIR/fw.log"
    grep -q "add: blocked 203.0.113.7 (rule 100013" "$BLOCK_C2_LOG"
    grep -Eq '^[0-9]{4}/[0-9]{2}/[0-9]{2} [0-9:]{8} active-response/bin/block-c2.sh: \{"version":1,.*"command":"add",.*"data":\{"srcip":"203.0.113.7"\}\}$' "$BLOCK_C2_LOG"
}

@test "add: abort from execd means already blocked, no firewall change" {
    run sh -c "{ $(declare -f alert); alert add 10.0.0.5 203.0.113.7; echo '{\"command\":\"abort\"}'; } | sh \"$SCRIPT\""
    [ "$status" -eq 0 ]
    [ ! -f "$TEST_TMPDIR/fw.log" ]
    grep -q "already blocked" "$BLOCK_C2_LOG"
}

@test "delete: removes the rules the add inserted" {
    sh -c "{ $(declare -f alert); alert add 10.0.0.5 203.0.113.7; echo '{\"command\":\"continue\"}'; } | sh \"$SCRIPT\"" >/dev/null
    run sh -c "$(declare -f alert); alert delete 10.0.0.5 203.0.113.7 | sh \"$SCRIPT\""
    [ "$status" -eq 0 ]
    [ "$(cat "$TEST_TMPDIR/rules")" = "0" ]
    grep -q "delete: unblocked 203.0.113.7" "$BLOCK_C2_LOG"
    grep -q '"command":"delete".*"data":{"srcip":"203.0.113.7"}' "$BLOCK_C2_LOG"
}

@test "no public address: logs and exits without touching the firewall" {
    run sh -c "$(declare -f alert); alert add 10.0.0.5 10.0.0.9 | sh \"$SCRIPT\""
    [ "$status" -eq 0 ]
    [ ! -f "$TEST_TMPDIR/fw.log" ]
    grep -q "nothing blocked" "$BLOCK_C2_LOG"
}
