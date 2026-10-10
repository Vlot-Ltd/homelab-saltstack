# PEP-HL-SLT-013: Remove local package mirror POC

**ID:** PEP-HL-SLT-013  
**Title:** Remove local package mirror POC  
**Author:** Timo Vlot  
**Status:** Draft  
**Type:** Infrastructure  
**Priority:** Low  
**Created:** 2026-10-10  
**Updated:** 2026-10-10  
**Supersedes:** N/A  
**Superseded-By:** N/A  

## Abstract

The homelab local package mirror (apt-mirror, moving to debmirror) was a proof of concept for work. The work version is built and runs there, so the homelab doesn't need one. This PEP removes what the POC left behind on `patch` and frees its storage. It does not build a mirror.

## Motivation

Leftovers found on `patch` on 2026-10-10:

- NFS mount `10.1.1.12:/mnt/datapool/aptmirror` on `/var/mirror` (in `/etc/fstab`), holding **765 GB** on the TrueNAS `datapool`
- nginx site `apt-mirror` enabled (port 8080), alongside PatchMon's own site
- `/etc/cron.d/apt-mirror`, every line commented out (no sync running)
- Package `apt-mirror` 0.5.4-2 installed

No Salt state or pillar for the mirror exists in this repo. `zabbix`, `postgres`, `docker`, `friday` and `netbox` have no apt sources pointing at the mirror; the other minions weren't checked.

Freeing the 765 GB also shrinks the TrueNAS to native Proxmox ZFS migration.

## Specification

### Requirements

- No minion's apt sources point at the mirror (check all minions first)
- PatchMon's nginx site keeps working
- The dataset is only destroyed once nothing uses it

### Implementation Approach

Manual cleanup on `patch` and TrueNAS. Nothing to add to Salt.

### Success Criteria

- `salt '*' cmd.run 'grep -rl 8080 /etc/apt/sources.list /etc/apt/sources.list.d/'` returns nothing
- `/var/mirror` unmounted and gone from `/etc/fstab`; `apt-mirror` purged; `/etc/cron.d/apt-mirror` and the nginx site removed; `nginx -t` passes and PatchMon loads
- The `aptmirror` dataset is gone from TrueNAS and its space is free

## Implementation Plan

### Phase 1: check nothing uses it

1. `salt '*' cmd.run 'grep -rl 8080 /etc/apt/sources.list /etc/apt/sources.list.d/'`; fix any hit first

### Phase 2: remove it from `patch`

1. `rm /etc/nginx/sites-enabled/apt-mirror`, `nginx -t`, `systemctl reload nginx`; check PatchMon loads
2. `rm /etc/cron.d/apt-mirror /etc/nginx/sites-available/apt-mirror`
3. `apt purge apt-mirror`
4. `umount /var/mirror`, remove the line from `/etc/fstab`, `rmdir /var/mirror`

### Phase 3: free the storage

1. Snapshot or leave the `aptmirror` dataset for a week, then destroy it on TrueNAS

## Testing Strategy

The success-criteria checks above, plus a `pkg.upgrade test=True` on one minion to show apt still resolves.

## Documentation Requirements

Mark the vault note `local-package-mirror-setup` as the work POC record, not a homelab plan.

## Risks and Mitigation

- A minion still uses the mirror: Phase 1 catches it.
- The nginx change breaks PatchMon: only the separate `apt-mirror` site is touched; backout is restoring the symlink.

**Backout:** until Phase 3, everything is reversible: restore the symlink, the fstab line and the cron file, reinstall `apt-mirror`. After Phase 3 the data is gone; it can be re-synced from upstream if ever needed.

## References

- Vault: `20-areas/homelab/local-package-mirror-setup.md`
- Vault: `20-areas/homelab/truenas-to-proxmox-zfs-migration.md`

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 0.1 | 2026-10-10 | Timo Vlot | Raised as a debmirror state |
| 0.2 | 2026-10-10 | Timo Vlot | Rescoped: homelab mirror not needed (built at work instead); cleanup of the POC only |
