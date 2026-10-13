# PEP-HL-SLT-021: NetBox host resources from Salt, kept current

**ID:** PEP-HL-SLT-021  
**Title:** NetBox host resources from Salt, kept current  
**Author:** Timo Vlot  
**Status:** Draft  
**Type:** Feature  
**Priority:** Low  
**Created:** 2026-10-13  
**Updated:** 2026-10-13  
**Supersedes:** N/A  
**Superseded-By:** N/A  

## Abstract

Extend netbox-sync-minions.py so NetBox holds and keeps current each host's resources (vCPUs, memory, disks) and platform (OS) from Salt grains, and run it on a schedule with a Vault-held token instead of by hand.

## Motivation

On 2026-10-13 `tools/netbox-sync-minions.py` put every Salt minion into NetBox (8 VMs,
3 devices: `proxmox`, `wopr`, `nlremote.taile3eee.ts.net`) plus two hand-listed
appliances (`homeassistant`, `truenas`), with interfaces, LAN and Tailscale IPs and
primary IPs. NetBox still has no CPU, memory, disk or OS details for any of them, and
nothing keeps it current: the script runs by hand with a temporary token.

## Specification

### Requirements

- VMs: `vcpus`, `memory` (MB) and disks (NetBox 4.x virtual disk components, which sum
  into `disk`) from grains (`num_cpus`, `mem_total`, block devices).
- All hosts: `platform` from grains (`os`, `osrelease`, e.g. "Ubuntu 24.04"), created
  if missing.
- Devices: same platform; CPU/memory go in custom fields or a comment, since Devices
  have no vCPU/memory fields (decide in design).
- Same rules as now: dry run by default, only writes what differs, never deletes.
- Scheduled run (Salt schedule or cron on the master), with a permanent NetBox token
  scoped to what the script writes, stored in Vault, never in the repo or argv.

### Out of scope

- Appliances (`homeassistant`, `truenas`): no grains; stay as fixed entries.
- Proxmox API as the source (it knows VM allocation, which can differ from what the
  guest sees). Possible later; grains first.
- The NetBox ext_pillar and `/etc/hosts` from NetBox (the vault note homelab-tailscale-https).

### Success Criteria

- Every minion's NetBox record shows vCPUs, memory, disk and platform matching the host.
- Resizing a VM shows up in NetBox after the next scheduled run, with no manual step.
- A scheduled run with nothing changed writes nothing (Change Log stays quiet).

## Implementation Plan

### Phase 1: Resources and platform

- Add the grains to the script's Salt calls; extend `sync_host`.
- Dry run, compare against the Proxmox UI for two VMs, apply.

### Phase 2: Schedule

- Permanent token in Vault; the job reads it at run time.
- Schedule on the master; failures reach Zabbix (exit code or log item).

## Testing Strategy

- Dry run before every apply; second dry run shows 0 changes.
- Resize a test VM's memory, run, check NetBox and the Change Log.

Backout: `git revert`; NetBox Change Log lists every write for manual reversal.

## Documentation Requirements

- Script docstring; note in the vault note homelab-tailscale-https Workstream 2.

## Risks and Mitigation

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Grains disk list includes non-VM disks (loop, ZFS zvols) | Wrong disk totals | Medium | Filter by device type; compare with Proxmox in dry run |
| Scheduled token leaks | Write access to NetBox | Low | Vault, scoped permissions, expiry plus rotation |
| Scheduled run overwrites hand edits | Lost manual data | Medium | Script only owns the fields it sets; document them |

## References

- `tools/netbox-sync-minions.py` (`53e5c3a`, `8cbaef3`)
- PEP-HL-SLT-011 (NetBox Salt takeover), PEP-HL-SLT-010 (gitfs, where the work started)

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 0.1 | 2026-10-13 | Timo Vlot | Initial draft |
