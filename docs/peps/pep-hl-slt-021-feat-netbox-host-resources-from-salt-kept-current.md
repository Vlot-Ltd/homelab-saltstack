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

### Field ownership and drift (added 2026-10-13)

NetBox is meant to become the source of truth, so each field gets exactly one writer:

- **OpenTofu** (future, homelab-terraform PEP-HL-TOFU-002): name, cluster, site, role,
  interface and LAN IP, set when the VM is created, IP allocated from NetBox IPAM.
- **This script**: observed facts only: Tailscale IP, platform, vCPUs, memory, disks.
  Once Tofu owns identity and LAN IP, the script must stop writing those and report
  differences instead.
- **Salt reactor** on minion key accept (`salt/key` event) runs the script for that
  one minion, so a host built outside Tofu still appears without a manual run.
- **Drift check**: the scheduled run in dry-run mode sends "changes planned" and
  "warnings" to Zabbix; a trigger on > 0 catches a host missing from NetBox, or NetBox
  disagreeing with the host. One item, not a set of hand-written checks.

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

### Phase 2: Schedule, reactor, drift alert

- Permanent token in Vault; the job reads it at run time.
- Schedule on the master: apply for script-owned fields, dry run for the rest.
- Reactor on `salt/key` accept runs the script with `--target <minion>`.
- Zabbix item for changes planned and warnings; trigger on > 0.

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
