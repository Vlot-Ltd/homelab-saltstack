# PEP-HL-SLT-022: Hosts file from the Salt mine

**ID:** PEP-HL-SLT-022  
**Title:** Hosts file from the Salt mine  
**Author:** Timo Vlot  
**Status:** Draft  
**Type:** Feature  
**Priority:** Medium  
**Created:** 2026-10-13  
**Updated:** 2026-10-13  
**Supersedes:** N/A  
**Superseded-By:** N/A  

## Abstract

Build /etc/hosts on every minion from the Salt mine (each minion publishes its LAN and Tailscale IPs) plus a short static pillar list for non-minions, replacing the hand-kept hosts_entries list. Replaces the plan to build it from NetBox.

## Motivation

`/etc/hosts` on every minion comes from `pillar/common/hosts.sls`, a hand-kept list
(LAN only, no `nlremote`, no Tailscale). The plan was to build it from NetBox through
an external pillar. Decided 2026-10-13 not to: the stock `netbox` ext_pillar only gives
each minion its own record, so it would need a custom ext_pillar, and NetBox itself (a
VM, Postgres, Redis, upgrades) is too much to run for ~15 hosts. Salt already knows
every minion's LAN and Tailscale IP; the Salt mine shares that with all minions. NetBox
is retired in PEP-HL-SLT-023.

## Specification

### Requirements

- Each minion publishes two mine functions, set in common pillar:
  ```yaml
  mine_functions:
    lan_ip:
      mine_function: network.ip_addrs
      cidr: 192.168.0.0/24
    ts_ip:
      mine_function: network.ip_addrs
      interface: tailscale0
  ```
- `salt/common/hosts.sls` builds entries from `salt['mine.get']('*', 'lan_ip')` and
  `('*', 'ts_ip')`. Name: the minion ID's first label (`nlremote.taile3eee.ts.net` →
  `nlremote`), plus `<name>.<default_domain>` as now.
- Address choice: the LAN IP if the host has one in `192.168.0.0/24`, else its
  Tailscale IP (covers `nlremote`). Per-host override in pillar if ever needed.
- Non-minions (`truenas` 192.168.0.3, `homeassistant` 192.168.0.24, and any others)
  stay as a short static pillar list, renamed `hosts_static`.
- The managed entries live in one marked block (`file.blockreplace`), so a removed
  host disappears from `/etc/hosts` on the next run. Today's `host.present` never
  removes anything (`colossus` needed a manual `hosts.rm_host`, 2026-10-13).
- The `docker:services` container entries keep working; `docker:host_tailscale_ip`
  can come from `docker`'s `ts_ip` mine value instead of pillar.

### Out of scope

- A "used/free IPs" file for OpenTofu from the same mine data: follow-on, see the vault
  project homelab-vm-provisioning-revival.
- Tailscale Services per host: PEP-HL-SLT-019.

### Success Criteria

- On every minion, the managed block lists every responding minion and the static
  hosts, with the same LAN IPs as the current `/etc/hosts` for the hosts in both.
- `nlremote` resolves to its Tailscale IP.
- A new minion appears on all others after `mine.update` and a highstate, with no
  pillar edit. A deleted key (`salt-key -d`) drops out the same way.

## Implementation Plan

### Phase 1: Mine

- Add `mine_functions` to common pillar; `salt '*' saltutil.refresh_pillar`, then
  `salt '*' mine.update`.
- Check: `salt salt mine.get '*' lan_ip` and `ts_ip` list every minion.

### Phase 2: Hosts state

- Rewrite `salt/common/hosts.sls` with `file.blockreplace`; `hosts_entries` →
  `hosts_static` with only the non-minions.
- Before the switch: back up `/etc/hosts` on each minion
  (`salt '*' cmd.run 'cp -a /etc/hosts /etc/hosts.pre-mine'`).
- Remove the old per-entry lines the first run would leave behind (the block replaces
  them; old `host.present` lines outside the block need one cleanup).

## Testing Strategy

- `salt docker state.apply common.hosts test=True`: the diff shows the block and the
  removal of the old lines, nothing else.
- Compare `getent hosts zabbix vault truenas nlremote` on `docker` before and after.
- Roll out: `docker`, then `salt`, then `'*'`.

Backout: `git revert` this PEP's commits, then
`salt '*' cmd.run 'cp -a /etc/hosts.pre-mine /etc/hosts'`.

## Documentation Requirements

- Comment in `hosts.sls` on where entries come from and how to add a non-minion.

## Risks and Mitigation

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| A minion is down when the mine updates | Its entry goes stale or missing | Low | Mine data is cached on the master until the key is deleted |
| Block and old lines both present | Duplicate names | Medium | One-off cleanup in Phase 2, checked with `getent` |
| Wrong interface picked for LAN IP (Docker bridges) | Wrong IP in hosts | Low | `cidr: 192.168.0.0/24` filter |

## References

- PEP-HL-SLT-023 (retire NetBox), PEP-HL-SLT-011 and 021 (rejected, NetBox-based)
- Salt mine: `mine_functions`, `mine.get`

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 0.1 | 2026-10-13 | Timo Vlot | Initial draft |
