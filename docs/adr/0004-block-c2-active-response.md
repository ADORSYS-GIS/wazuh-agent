# ADR-0004: Block the Remote End of Malware/C2 Traffic on Linux Agents

> We ship our own active response script, `block-c2.sh`, that blocks the public address of a Suricata malware/C2 flow for 10 minutes. The stock `firewall-drop` can't read Suricata's address fields, and when the alert is for outbound traffic it would block the agent's own address.

## Metadata

| Field             | Value                                                                                                                                                                                                                                                                                                                                        |
| :---------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Document ID**   | ADR-0004                                                                                                                                                                                                                                                                                                                                     |
| **Status**        | `Proposed`                                                                                                                                                                                                                                                                                                                                   |
| **Date**          | 2026-11-03                                                                                                                                                                                                                                                                                                                                   |
| **Deciders**      | SIEM Security Engineering Team                                                                                                                                                                                                                                                                                                               |
| **Governs**       | `files/active-response/linux/block-c2.sh`; the block-c2 install step in `scripts/linux/setup-agent.sh`; in ADORSYS-GIS/wazuh-helm: the `block-c2` `<command>` and `<active-response>` in `charts/wazuh/files/configs/template.config.conf.xml`, rules 100013, 100025, 100026 in `charts/wazuh/files/configs/rules/rules.suricata-custom.xml` |
| **Amends**        | N/A                                                                                                                                                                                                                                                                                                                                          |
| **Amended by**    | N/A                                                                                                                                                                                                                                                                                                                                          |
| **Supersedes**    | N/A                                                                                                                                                                                                                                                                                                                                          |
| **Superseded by** | N/A                                                                                                                                                                                                                                                                                                                                          |

## Context

Suricata runs on the agents and its alerts reach the manager. Rule 100013 (level 13) fires when an Emerging Threats `MALWARE`, `TROJAN`, `CNC` or `MOBILE_MALWARE` signature matches, which is the strongest automatic sign we have that a machine is talking to malware infrastructure. Until now nothing happened after the alert: an analyst had to see it and act by hand. The IRP-Malware playbook asks for containment within minutes, and the alert can fire at night.

Wazuh's stock `firewall-drop` response can't do this job:

- It reads `data.srcip`. Suricata alerts carry `data.src_ip` and `data.dest_ip`, so `firewall-drop` gets no address.
- Even with the field renamed, outbound C2 alerts have this machine as the source. Blocking the source would cut the agent off its own address and leave the C2 server reachable.

We also need to see what the response did. A block that leaves no alert can't be audited, and an analyst can't lift it if they don't know it is there.

The forces that decided this: containment has to happen on the machine itself within seconds and without an analyst, it must never block the machine, its gateway, its DNS or the private/NetBird ranges, and every block and unblock has to show up as an alert.

## Decision

We will:

1. Ship `files/active-response/linux/block-c2.sh` in this repo. `scripts/linux/setup-agent.sh` downloads it, checks it against `checksums.sha256`, and installs it into the agent's active-response `bin` directory as `root:wazuh`, mode `750`.
2. Speak the Wazuh 4.2+ active response protocol: one JSON message on stdin. On `add` the script sends `check_keys` with the target IP and stops if execd answers `abort` (already blocked).
3. Pick the target from `data.src_ip` and `data.dest_ip`: the side that is public and not this machine. Never block private (RFC 1918), CGNAT/NetBird (`100.64.0.0/10`), loopback, link-local, multicast or unspecified addresses (IPv4 and IPv6), the default gateway, or the `nameserver` entries in `/etc/resolv.conf`. If no side qualifies, log it and exit 0 without touching the firewall.
4. Block in both directions: `iptables`/`ip6tables` `DROP` rules inserted at the top of `OUTPUT` (destination) and `INPUT` (source), tagged with the comment `wazuh-block-c2`. When `iptables` is missing, use `nft`, with the address added to a set in the table `inet wazuh_c2`. On `delete`, remove exactly those rules or set elements.
5. Report every block and unblock in Wazuh's own active-response log format, so the manager decodes it (`ar_log_json`, rule 650) and raises rule 100025 (blocked, level 6) and rule 100026 (unblocked, level 4). Rule 100026 is level 4 so it wins over stock rule 657.
6. On the manager (ADORSYS-GIS/wazuh-helm), declare the `block-c2` command with `timeout_allowed` and an `<active-response>` with `location` `local`, `rules_id` `100013`, `timeout` `600`. The response runs only on the agent that raised the alert.
7. Roll out to dev first (`feat/shuffle-soar`, the dev deploy branch). Prod comes from `main` after the dev soak listed under Done when.

## Options considered

| Option                                                     | Verdict  | Why (one line)                                                                                                                  |
| :--------------------------------------------------------- | :------- | :------------------------------------------------------------------------------------------------------------------------------ |
| Custom `block-c2.sh` on the agent, triggered by 100013     | Adopted  | Reads Suricata's fields, picks the remote side, works offline from the analyst, and reports each action as an alert.            |
| Stock `firewall-drop` on 100013                            | Rejected | Reads `data.srcip`, which Suricata alerts don't have, so it gets no address.                                                    |
| Map `src_ip` to `srcip` in a decoder, then `firewall-drop` | Rejected | On outbound C2 the source is this machine, so it would block the agent's own address and leave the C2 server reachable.         |
| Block in SOAR (Shuffle) or at the DNS filter (AdGuard)     | Rejected | Adds a network round trip and a dependency that must be up at night. A DNS block misses C2 that connects to an IP directly.     |
| Isolate the whole host on 100013                           | Rejected | A false positive on one signature would take a person's machine offline. Blocking one address for 10 minutes limits the damage. |

## Consequences

**Not part of this decision:** the tuning of rule 100013 itself (which signatures count as malware/C2), the Web Filtering dashboard Response tab (ADORSYS-GIS/wazuh-helm#566), and the wording of the IRP-Malware and UCD-C2Containment pages. The 600-second timeout is a starting value, not part of the decision; change it in the manager config without a new ADR.

### Impact

**Benefits**

- A machine that talks to known malware infrastructure loses that connection within seconds, without waiting for an analyst.
- Every block and unblock is an alert (100025/100026) on the same agent, so the dashboard and IRP have an audit trail.
- The block expires on its own, so a wrong block costs at most 10 minutes for one address on one machine.

**Costs**

- One more script to maintain in this repo, with its own bats tests (`scripts/tests/test-block-c2.bats`).
- The manager config and two rules in wazuh-helm have to stay in step with the script's log format.

**Risks**

- A false positive on a shared address (CDN, cloud load balancer) cuts that machine off every site behind the address for 10 minutes. The blast radius is one agent.
- Another firewall tool on the host (`firewalld` reload, `ufw` reset) can flush the rules early. The block then ends without a 100026 alert.
- If the agent restarts before the timeout, execd may not run `delete`, and the rule stays until the host's firewall is reloaded or the machine reboots. This is not yet tested; see Done when.

### Accepted limits

- Linux only. On macOS and Windows agents, execd logs that the script is missing and nothing is blocked. Their firewalls (`pf`, Windows Firewall) need their own scripts, and that is a separate decision.
- Only Suricata rule 100013 triggers it. Agents without Suricata, or C2 that Suricata doesn't recognise, get no block.
- The rules don't survive a reboot. That is on purpose: the block is short-lived containment, not a permanent deny list.

### Done when

- [x] End-to-end test on the dev test VM: rule 100013 → 100025 (blocked `203.0.113.7`) → 100026 after 600 s.
- [ ] ADORSYS-GIS/wazuh-agent#276 merged and a release published that contains `block-c2.sh` and its checksum.
- [ ] Installed from that release and tested on an `iptables` host (Ubuntu) and an `nft`-only host (Debian 12 or RHEL 9).
- [ ] Agent restart during an active block tested, and what happened written down in the runbook.
- [ ] 7 days on dev with no block of a private, protected or legitimate business address.
- [ ] Runbook in `docs/operations/` that shows how to list and lift a `block-c2` block by hand.
- [ ] Manager config and rules 100025/100026 merged to ADORSYS-GIS/wazuh-helm `main` and live in prod.

### Revisit when

- Anything under Governs changes, or the Wazuh active response protocol changes (Wazuh 5).
- We add active response for macOS or Windows agents.
- A false-positive block reaches a user, or rule 100013's signature list is widened.
- At least once a year.

## Rollback

**When.** Linux users report that a site or service is unreachable, and `iptables -S | grep wazuh-block-c2` or `nft list table inet wazuh_c2` on their machine shows the address. Or rule 100025 fires much more often than rule 100013 has before.

**How, in order.**

1. In ADORSYS-GIS/wazuh-helm, revert only the `<active-response>` block for `block-c2`, in its own commit. Leave the `<command>` and rules 100025/100026 in place, so pending unblocks are still reported.
2. Let ArgoCD sync the revert. Don't edit the live manager config by hand: ArgoCD will put it back.
3. Leave the script on the agents. Without the manager's `<active-response>` it never runs.
4. Blocks that are already in place still end when execd runs `delete` at the timeout. Where the agent restarted in between, remove the rules on the host: `iptables -D OUTPUT -d <ip> -m comment --comment wazuh-block-c2 -j DROP` and `iptables -D INPUT -s <ip> -m comment --comment wazuh-block-c2 -j DROP` (or `ip6tables`), or `nft delete table inet wazuh_c2`.

## Evidence

| Claim                                                                                                                                         | Where                                                                                                                                                                                               |
| :-------------------------------------------------------------------------------------------------------------------------------------------- | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Rule 100013 matches ET `MALWARE`/`TROJAN`/`CNC`/`MOBILE_MALWARE` signatures, level 13                                                         | [rules.suricata-custom.xml#L68 @ f49b507](https://github.com/ADORSYS-GIS/wazuh-helm/blob/f49b5078b4afc67893acecc87e18b650b477f278/charts/wazuh/files/configs/rules/rules.suricata-custom.xml#L68)   |
| Rules 100025/100026 report block and unblock from `ar_log_json` (650)                                                                         | [rules.suricata-custom.xml#L229 @ f49b507](https://github.com/ADORSYS-GIS/wazuh-helm/blob/f49b5078b4afc67893acecc87e18b650b477f278/charts/wazuh/files/configs/rules/rules.suricata-custom.xml#L229) |
| Manager runs `block-c2` locally on 100013 with a 600 s timeout (dev)                                                                          | [template.config.conf.xml#L390 @ f49b507](https://github.com/ADORSYS-GIS/wazuh-helm/blob/f49b5078b4afc67893acecc87e18b650b477f278/charts/wazuh/files/configs/template.config.conf.xml#L390)         |
| Script's target selection, protected ranges, firewall and report format                                                                       | [block-c2.sh @ 944d0b6](https://github.com/ADORSYS-GIS/wazuh-agent/blob/944d0b65d095c3d5e82bbece32138a3b95518b6f/files/active-response/linux/block-c2.sh)                                           |
| Installer downloads and checks the script against `checksums.sha256`                                                                          | [setup-agent.sh#L361 @ 944d0b6](https://github.com/ADORSYS-GIS/wazuh-agent/blob/944d0b65d095c3d5e82bbece32138a3b95518b6f/scripts/linux/setup-agent.sh#L361)                                         |
| Dev end-to-end: 100013, then 100025 at 2026-11-02 20:56 UTC, 100026 at 21:06 UTC, agent `Yannick-Siewe-604ac3`, IP `203.0.113.7` (TEST-NET-3) | dev indexer, `wazuh-alerts-4.x-2026.11.02`, `rule.id` 100013/100025/100026                                                                                                                          |
| Prod raised no rule 100013 alert between 2026-10-27 and 2026-11-03                                                                            | prod indexer, `wazuh-alerts-*`, `rule.id: 100013`                                                                                                                                                   |

## References

- [Wazuh: custom active response scripts](https://documentation.wazuh.com/current/user-manual/capabilities/active-response/custom-active-response-scripts.html)
- [Wazuh: active response configuration](https://documentation.wazuh.com/current/user-manual/reference/ossec-conf/active-response.html)
- Confluence, space Wazuh: IRP-Malware (page 2327609509), UCD-C2Containment (page 3240165877)
- [ADR writing guide](https://github.com/ADORSYS-GIS/wazuh/blob/main/docs/adr/GUIDE.md)

## Solution implementation

| Kind  | Tracking                    | Status            | What it covers                                                       |
| :---- | :-------------------------- | :---------------- | :------------------------------------------------------------------- |
| Issue | ADORSYS-GIS/wazuh#2283      | Open              | Web filtering 4.x work, under which C2 containment was started       |
| PR    | ADORSYS-GIS/wazuh-agent#276 | Open              | `block-c2.sh`, installer step, bats tests                            |
| PR    | ADORSYS-GIS/wazuh-helm#567  | Merged 2026-11-02 | `block-c2` command and active response, dev (`feat/shuffle-soar`)    |
| PR    | ADORSYS-GIS/wazuh-helm#568  | Merged 2026-11-02 | Rules 100025/100026 for block and unblock, dev (`feat/shuffle-soar`) |
