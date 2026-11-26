# block-c2 Runbook

How to see, lift and switch off the C2 containment block on Linux agents. The decision and its limits are in [ADR-0004](../../adr/0004-block-c2-active-response.md). The tests are in the [test plan](../../testing/block-c2-test-plan.md).

## What it does

When Suricata rule 100013 (malware or command-and-control traffic) fires on a Linux agent, the manager runs `block-c2.sh` on that agent. The script drops all traffic to and from the remote public address for 600 seconds, then removes the block. It never blocks private or NetBird addresses, the gateway, or the DNS servers.

| Alert  | Level | Meaning                                              |
| :----- | :---- | :--------------------------------------------------- |
| 100013 | 13    | Suricata saw malware/C2 traffic. Triggers the block. |
| 100025 | 6     | `block-c2 blocked <ip> on this host for 10 minutes`  |
| 100026 | 4     | `block-c2 removed the block on <ip>`                 |

## Is a host blocking an address?

In the dashboard, filter on the agent with `rule.id: (100025 OR 100026)`. A 100025 with no 100026 for the same `data.srcip` more than 10 minutes later means the block is still in place. That happens when execd crashed during the block (see "Stuck block").

On the host:

```sh
sudo iptables -S | grep wazuh-block-c2
sudo ip6tables -S | grep wazuh-block-c2
sudo nft list table inet wazuh_c2          # hosts without iptables
sudo grep block-c2 /var/ossec/logs/active-responses.log | tail -20
```

## Lift a block now

Use this when a block hits a legitimate service, after you have checked that the address isn't malicious (MISP, VirusTotal, the Suricata signature in the 100013 alert).

```sh
IP=203.0.113.7
sudo iptables -D OUTPUT -d "$IP" -m comment --comment wazuh-block-c2 -j DROP
sudo iptables -D INPUT  -s "$IP" -m comment --comment wazuh-block-c2 -j DROP
# IPv6: same two lines with ip6tables
# nft:  sudo nft delete element inet wazuh_c2 c2v4 "{ $IP }"   (c2v6 for IPv6)
```

Run each `-D` line until it reports that the rule doesn't exist: a second alert can add a second copy. When the timeout expires, execd's own `delete` finds nothing and logs "was not blocked". That is harmless.

Write down in the incident ticket that the block was lifted by hand, and why. No 100026 alert is raised for a manual removal.

## Stuck block

**Cause.** If `wazuh-execd` is killed or crashes while a block is active, the pending `delete` is lost and the block stays until the firewall is reloaded or the host reboots. A clean `systemctl restart wazuh-agent` doesn't cause this: execd runs the pending `delete` as it stops, so the block ends early and 100026 is raised.

**Fix.** Lift it by hand as above. If the same address triggers 100013 again first, that block's `delete` removes every matching rule, the stuck one included.

## Switch it off everywhere

Follow Rollback in [ADR-0004](../../adr/0004-block-c2-active-response.md#rollback). In short: in ADORSYS-GIS/wazuh-helm, revert only the `block-c2` `<active-response>` block, in its own commit, and let ArgoCD sync it. Leave the `<command>` and rules 100025/100026 in place. Active blocks still end at their timeout. The script can stay on the agents: it never runs without the manager's `<active-response>`.

Don't edit the live manager config by hand. ArgoCD puts it back within seconds.

## No block happened

| Check                              | How                                                                                                                |
| :--------------------------------- | :----------------------------------------------------------------------------------------------------------------- |
| Did 100013 fire for this agent?    | Dashboard, `rule.id: 100013`                                                                                       |
| Is the agent Linux?                | macOS and Windows agents have no script, so execd only logs an error.                                              |
| Is the script installed?           | `ls -l /var/ossec/active-response/bin/block-c2.sh`: owner `root:wazuh`, mode `750`. Installed by `setup-agent.sh`. |
| Was there a public remote address? | `active-responses.log`: "no public remote address in src … / dest …; nothing blocked"                              |
| Was the address already blocked?   | `active-responses.log`: "already blocked, skipped"                                                                 |
| Is there a firewall tool?          | `active-responses.log`: "no iptables or nft on this host"                                                          |
| Did the manager send the command?  | Manager `ossec.log`, and the agent's `ossec.log` for `wazuh-execd` errors                                          |

## Firewall tools on the host

`nft flush ruleset` removes the block. Depending on the backend, `firewalld --reload` or `ufw reload` may remove it too (not tested). Either way the block ends early without a 100026 alert, and the unblock at the timeout logs "was not blocked". If a host's firewall tool rewrites the rules often, the block won't hold there. Record that against the host.
