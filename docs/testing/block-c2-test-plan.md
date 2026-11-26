# block-c2 Active Response: Test Plan

Tests for the C2 containment active response decided in [ADR-0004](../adr/0004-block-c2-active-response.md): `files/active-response/linux/block-c2.sh`, run by the manager on Suricata rule 100013.

## Scope

| In scope                                                               | Out of scope                                                                             |
| :--------------------------------------------------------------------- | :--------------------------------------------------------------------------------------- |
| Choosing the target address, protected ranges                          | Which Suricata signatures count as C2 (rule 100013 tuning)                               |
| `iptables`/`ip6tables` and `nft` blocking, both directions             | macOS and Windows agents (the script is Linux only)                                      |
| The Wazuh 4.x active response protocol (`check_keys`, `add`, `delete`) | Manager-side rules 100025/100026 (tested in ADORSYS-GIS/wazuh-helm with `wazuh-logtest`) |
| Behaviour across an agent restart and an execd crash                   | Load testing                                                                             |

## Test levels

| Level      | What                                                   | How                                                                | When                                                                   |
| :--------- | :----------------------------------------------------- | :----------------------------------------------------------------- | :--------------------------------------------------------------------- |
| Unit       | Target choice, protected ranges, protocol, add/delete  | `bats scripts/tests/test-block-c2.bats` (8 tests, firewall mocked) | Every PR, in CI                                                        |
| Firewall   | Real rules on real firewalls, traffic actually dropped | Script fed execd messages in privileged containers (below)         | Before each release that changes the script                            |
| End to end | Real manager + agent 4.14.x, real execd, real timeout  | Manager and agent containers (below)                               | Before each release that changes the script, and after a Wazuh upgrade |
| Dev        | Real Suricata alert on a real machine                  | Dev test VM, alerts 100013 → 100025 → 100026 in the dev indexer    | Before prod rollout                                                    |

## Cases and results

Run on 2026-11-03 against `main` at `ad79f12`, Wazuh agent and manager `4.14.6`.

### Firewall level

Ubuntu 24.04 (`iptables`, nft backend) and Debian 12 with only `nftables` installed. Each case is checked by counting the `wazuh-block-c2` rules (`iptables -S`) or the set elements (`nft list table inet wazuh_c2`).

| #   | Case                                                      | Expected                                                                | Ubuntu (iptables) | Debian 12 (nft) |
| :-- | :-------------------------------------------------------- | :---------------------------------------------------------------------- | :---------------- | :-------------- |
| F1  | Outbound C2, this host → `203.0.113.7`                    | Sends `check_keys`, then blocks `203.0.113.7` (2 rules: OUTPUT + INPUT) | Pass              | Pass            |
| F2  | Same address again, execd answers `abort`                 | Nothing added, log "already blocked"                                    | Pass              | Pass            |
| F3  | Inbound IPv6, `2001:db8::66` → this host                  | Blocks `2001:db8::66` with `ip6tables` / the `c2v6` set                 | Pass              | Pass            |
| F4  | Both sides private, `10.0.0.5` → `192.168.1.9`            | Nothing blocked, log "no public remote address"                         | Pass              | Pass            |
| F5  | Remote side is the default gateway                        | Nothing blocked                                                         | Pass              | Pass            |
| F6  | Traffic to `1.1.1.1:443` before, during and after a block | connected / no connection / connected                                   | Pass              | Pass            |
| F7  | `delete` for both blocked addresses                       | All rules / set elements removed, unblock line logged                   | Pass              | Pass            |

### End to end

A `wazuh/wazuh-manager:4.14.6` container and an Ubuntu 24.04 agent (`wazuh-agent=4.14.6-1`, privileged) on one Docker network. The manager has a test rule 100013 (child of stock 86601, `alert.signature` `^ET MALWARE`) and the production `block-c2` command and active response, with the timeout cut to `60` s. The agent reads `/tmp/eve.json` as `json`. Writing one Suricata-style alert line there triggers the chain.

| #   | Case                                                                         | Expected                                                  | Result                                                                                          |
| :-- | :--------------------------------------------------------------------------- | :-------------------------------------------------------- | :---------------------------------------------------------------------------------------------- |
| E1  | Alert for `1.1.1.1`                                                          | Blocked within seconds, unblocked by execd at the timeout | Pass: blocked 12:32:10, unblocked 12:33:11                                                      |
| E2  | Clean agent restart (`wazuh-control restart`) 12 s into a block of `8.8.8.8` | Unknown before this test                                  | execd runs `delete` when it shuts down: block lifted early (11 s), unblock logged, no rule left |
| E3  | execd killed (`kill -9`) 9 s into a block of `9.9.9.9`, agent restarted      | Unknown before this test                                  | **Block stays** after the timeout, no unblock logged. See the runbook to lift it.               |
| E4  | After E3, a new alert for `9.9.9.9`                                          | New block, and its `delete` removes every matching rule   | Pass: 4 rules during the block, 0 after the timeout                                             |

### Dev

| #   | Case                                                          | Result                                                       |
| :-- | :------------------------------------------------------------ | :----------------------------------------------------------- |
| D1  | Test VM `Yannick-Siewe-604ac3`, rule 100013 for `203.0.113.7` | 2026-11-02: 100025 at 20:56 UTC, 100026 at 21:06 UTC (600 s) |

## How to run

**Unit:** `bats scripts/tests/test-block-c2.bats`

**Firewall level:** save the messages below as a script and run it in `docker run --rm --privileged ubuntu:24.04` (install `iptables iproute2`) and `debian:12` (install `nftables iproute2`), with the script mounted. Set `BLOCK_C2_LOG` to a temp file. The second line on stdin is execd's answer to `check_keys`:

```sh
L=$(hostname -I | awk '{print $1}')
printf '{"version":1,"command":"add","parameters":{"alert":{"rule":{"id":"100013"},"data":{"src_ip":"%s","dest_ip":"1.1.1.1"}}}}\n{"command":"continue"}\n' "$L" \
  | sh block-c2.sh
iptables -S | grep wazuh-block-c2      # or: nft list table inet wazuh_c2
```

**End to end:** on the manager, add the test rule to `local_rules.xml` and the `<command>` and `<active-response>` from ADORSYS-GIS/wazuh-helm `template.config.conf.xml` with `<timeout>60</timeout>`. Install `wazuh-agent` 4.14.x on a privileged Ubuntu container, enrol it, install the script as `root:wazuh` `750` in `/var/ossec/active-response/bin/`, add a `json` `<localfile>` for `/tmp/eve.json`, then append:

```json
{
  "timestamp": "2026-11-03T12:00:00.000000+0000",
  "event_type": "alert",
  "src_ip": "<agent ip>",
  "src_port": 50000,
  "dest_ip": "1.1.1.1",
  "dest_port": 443,
  "proto": "TCP",
  "alert": { "signature": "ET MALWARE test beacon", "signature_id": 2000001 }
}
```

Check `/var/ossec/logs/active-responses.log` and `iptables -S` on the agent.

## Exit criteria for prod

- Unit, firewall and end-to-end cases pass on the release being rolled out.
- D1 holds, and 7 days on dev with no block of a private, protected or legitimate business address (ADR-0004, Done when).
