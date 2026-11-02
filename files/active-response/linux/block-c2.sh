#!/bin/sh
#
# Wazuh Active Response - block the remote end of malware / C2 traffic (Linux)
#
# Triggered by the manager on Suricata rule 100013 ("malware or command-and-control traffic"). Suricata alerts carry
# data.src_ip / data.dest_ip, not data.srcip, so the stock firewall-drop cannot use them. This script picks the
# public side of the flow (the remote host, never this machine or a private address), drops traffic to and from it
# with iptables (or nft when iptables is missing), and removes the block again when the manager's timeout expires.
#
# Protocol: Wazuh 4.2+ active response. One JSON message on stdin ("add" or "delete"). On "add" the script asks
# execd whether the key (the IP) is already blocked ("check_keys") and stops on "abort".
#
# Never blocked: private, CGNAT/NetBird (100.64.0.0/10), loopback, link-local, multicast and unspecified addresses,
# the default gateway, and the DNS servers in /etc/resolv.conf.

LOGFILE="${BLOCK_C2_LOG:-/var/ossec/logs/active-responses.log}"
NAME="block-c2"
COMMENT="wazuh-block-c2"

log() {
    printf '%s %s: %s\n' "$(date '+%Y/%m/%d %H:%M:%S')" "$NAME" "$*" >> "$LOGFILE" 2>/dev/null
}

# First value of a JSON string field, e.g. json_field "$msg" dest_ip. Enough for Wazuh's flat Suricata fields.
json_field() {
    printf '%s' "$1" | sed -n "s/.*\"$2\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -n 1
}

is_ipv4() {
    printf '%s' "$1" | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}$' || return 1
    for o in $(printf '%s' "$1" | tr '.' ' '); do [ "$o" -le 255 ] || return 1; done
    return 0
}

is_ipv6() {
    printf '%s' "$1" | grep -Eq '^[0-9A-Fa-f:]+$' && printf '%s' "$1" | grep -q ':'
}

# 0 when the address must never be blocked.
is_protected() {
    ip="$1"
    if is_ipv4 "$ip"; then
        a=$(echo "$ip" | cut -d. -f1); b=$(echo "$ip" | cut -d. -f2)
        [ "$a" -eq 0 ] || [ "$a" -eq 10 ] || [ "$a" -eq 127 ] || [ "$a" -ge 224 ] && return 0
        [ "$a" -eq 169 ] && [ "$b" -eq 254 ] && return 0
        [ "$a" -eq 172 ] && [ "$b" -ge 16 ] && [ "$b" -le 31 ] && return 0
        [ "$a" -eq 192 ] && [ "$b" -eq 168 ] && return 0
        [ "$a" -eq 100 ] && [ "$b" -ge 64 ] && [ "$b" -le 127 ] && return 0
    elif is_ipv6 "$ip"; then
        l=$(printf '%s' "$ip" | tr 'A-F' 'a-f')
        case "$l" in
            ::|::1|fe8*|fe9*|fea*|feb*|fc*|fd*|ff*) return 0 ;;
        esac
    else
        return 0 # not an IP: never act on it
    fi
    for p in $(protected_hosts); do [ "$p" = "$ip" ] && return 0; done
    return 1
}

protected_hosts() {
    if [ -n "${BLOCK_C2_PROTECTED+x}" ]; then
        printf '%s\n' "$BLOCK_C2_PROTECTED"
        return
    fi
    ip route show default 2>/dev/null | awk '/default/ {print $3}'
    awk '/^nameserver/ {print $2}' /etc/resolv.conf 2>/dev/null
}

# The remote end: the public address of the flow. Empty when there is none (both sides private or protected).
pick_target() {
    src="$1"; dst="$2"
    if [ -n "$dst" ] && ! is_protected "$dst"; then
        if [ -z "$src" ] || is_protected "$src" || is_local "$src"; then echo "$dst"; return; fi
    fi
    if [ -n "$src" ] && ! is_protected "$src" && ! is_local "$src"; then echo "$src"; return; fi
    if [ -n "$dst" ] && ! is_protected "$dst" && ! is_local "$dst"; then echo "$dst"; return; fi
}

# 0 when the address belongs to this machine.
is_local() {
    if [ -n "${BLOCK_C2_LOCAL+x}" ]; then
        for l in $BLOCK_C2_LOCAL; do [ "$l" = "$1" ] && return 0; done
        return 1
    fi
    ip -o addr show 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | grep -qx "$1"
}

fw() { # fw add|delete <ip>
    op="$1"; ip="$2"
    if is_ipv6 "$ip"; then ipt=ip6tables; fam=ip6; else ipt=iptables; fam=ip; fi
    if command -v "$ipt" >/dev/null 2>&1; then
        if [ "$op" = add ]; then
            "$ipt" -I OUTPUT -d "$ip" -m comment --comment "$COMMENT" -j DROP &&
                "$ipt" -I INPUT -s "$ip" -m comment --comment "$COMMENT" -j DROP
        else
            rc=1
            while "$ipt" -D OUTPUT -d "$ip" -m comment --comment "$COMMENT" -j DROP 2>/dev/null; do rc=0; done
            while "$ipt" -D INPUT -s "$ip" -m comment --comment "$COMMENT" -j DROP 2>/dev/null; do rc=0; done
            return $rc
        fi
    elif command -v nft >/dev/null 2>&1; then
        set4="c2v4"; [ "$fam" = ip6 ] && set4="c2v6"
        if [ "$op" = add ]; then
            nft list table inet wazuh_c2 >/dev/null 2>&1 || nft -f - <<'EOF'
table inet wazuh_c2 {
    set c2v4 { type ipv4_addr; }
    set c2v6 { type ipv6_addr; }
    chain out { type filter hook output priority 0; ip daddr @c2v4 drop; ip6 daddr @c2v6 drop; }
    chain in { type filter hook input priority 0; ip saddr @c2v4 drop; ip6 saddr @c2v6 drop; }
}
EOF
            nft add element inet wazuh_c2 "$set4" "{ $ip }"
        else
            nft delete element inet wazuh_c2 "$set4" "{ $ip }"
        fi
    else
        log "no iptables or nft on this host, cannot block $ip"
        return 1
    fi
}

main() {
    IFS= read -r msg || true  # the last line may lack a newline; read still sets msg
    [ -n "$msg" ] || { log "no input"; exit 1; }
    cmd=$(json_field "$msg" command)
    src=$(json_field "$msg" src_ip)
    dst=$(json_field "$msg" dest_ip)
    rule=$(printf '%s' "$msg" | sed -n 's/.*"rule"[[:space:]]*:[[:space:]]*{[^}]*"id"[[:space:]]*:[[:space:]]*"\([0-9]*\)".*/\1/p' | head -n 1)
    target=$(pick_target "$src" "$dst")
    if [ -z "$target" ]; then
        log "$cmd: rule $rule, no public remote address in src $src / dest $dst; nothing blocked"
        exit 0
    fi
    case "$cmd" in
        add)
            printf '{"version":1,"origin":{"name":"%s","module":"active-response"},"command":"check_keys","parameters":{"keys":["%s"]}}\n' "$NAME" "$target"
            IFS= read -r reply || true
            if [ "$(json_field "$reply" command)" = "abort" ]; then
                log "add: $target already blocked, skipped"
                exit 0
            fi
            if fw add "$target"; then log "add: blocked $target (rule $rule, src $src, dest $dst)"; else log "add: FAILED to block $target"; exit 1; fi
            ;;
        delete)
            if fw delete "$target"; then log "delete: unblocked $target (rule $rule)"; else log "delete: $target was not blocked"; fi
            ;;
        *)
            log "unknown command '$cmd'"
            exit 1
            ;;
    esac
}

[ "${BLOCK_C2_SOURCED:-0}" = 1 ] || main
