# PEP-HL-SLT-023: Retire NetBox

**ID:** PEP-HL-SLT-023  
**Title:** Retire NetBox  
**Author:** Timo Vlot  
**Status:** Implemented  
**Type:** Infrastructure  
**Priority:** Low  
**Created:** 2026-10-13  
**Updated:** 2026-10-15  
**Supersedes:** N/A  
**Superseded-By:** N/A  

## Abstract

Retire NetBox from the homelab: back up, then remove the VM, its Postgres database and role, Salt states and pillar, Vault secrets, monitoring, patching and Tailscale entries, and archive its vault notes after extracting what's worth keeping.

## Implementation record (2026-10-15)

Done in one session, by decision **without backups** ("if it ever comes back, start
clean"). Differences from the plan below:

- Zabbix: no `netbox` host existed (template already gone). PatchMon host and Tailscale
  node removed by hand.
- Salt repo (`122c13d`): `salt/application/netbox/` (incl. `initold.sls`,
  `superuser.sls` with its placeholder password), `pillar/application/netbox.sls`, both
  `pillar/top.sls` entries, the Homepage tile and `tools/netbox-sync-minions.py`.
  `postgres`'s pillar checked clean of `netbox` before the drop.
- `postgres`: database `netbox` and role **`netbox_user`** (not `netbox`) dropped with
  `DROP DATABASE netbox WITH (FORCE)`: Zabbix agent 2's Postgres plugin
  (`zabbixmonitor`) held an idle session.
- Proxmox: VM 110 destroyed with `--purge`. NetBox was never a Salt minion, so no key.
- Vault: no `secret/` mount ever existed; the only path was `salt/minions/netbox`
  (`netbox_secret`, `nmap_api`, `superuser_email`, `superuser_password`), deleted with
  `vault kv metadata delete`. No NetBox policy.
- Sweep of all minions for cron, timers and containers mentioning netbox or nmap:
  none (the nmap discovery ran on the NetBox VM itself).
- Found on the way, not NetBox: `pillar/application/manyfold.sls` uses `name:` instead
  of `name_key`/`password_key`, so `database.postgres` hasn't rendered since
  2026-07-18 (`064a055`). Separate fix.

## Motivation

NetBox was deployed (by hand, July 2026) to drive `/etc/hosts` through a Salt external
pillar. Decided 2026-10-13 that it isn't worth running: it's a VM plus Postgres and
Redis to patch and upgrade, it would never be run anywhere else, and the Salt mine
covers `/etc/hosts` (PEP-HL-SLT-022). Free-IP tracking for OpenTofu (`.2`-`.50`) can
come from Salt as well.

## Specification

### Inventory to remove

| Where | What |
|---|---|
| Proxmox | VM `netbox` |
| `postgres` | Database `netbox` and role `netbox` |
| Salt repo | `salt/application/netbox/` (all, incl. `initold.sls`, `files/configuration.py.jinja`); `pillar/application/netbox.sls`; `pillar/top.sls` `'netbox'` block and `application.netbox` under `'postgres'`; NetBox tile in `pillar/application/homepage.sls`; `tools/netbox-sync-minions.py` |
| Salt master | `salt-key -d netbox` |
| Vault | `secret/homelab/netbox/*` (`app`, `postgres`, `salt` if created) |
| Zabbix | Host `netbox` |
| PatchMon | Host `netbox` |
| Tailscale | Node `netbox` (admin console) |
| Vault notes | `netbox-deployment` and its links |

### Requirements

- Back up before removing: a final `vzdump` of the VM, and `pg_dump netbox` from
  `postgres`. Keep both for 30 days, then delete.
- Export the IPAM IP list (IPAM → IP Addresses → Export → CSV) for reference when
  building the free-IP list. IPs only, no secrets.
- Remove monitoring first (disable the Zabbix host) so the shutdown doesn't alert.
- Extract before archiving the vault notes (vault convention). Candidates: the external
  Postgres pattern, Zabbix systemd unit items, the PatchMon enrolment reminder.

### Out of scope

- PEP-HL-SLT-003 (Postgres SQL injection fix): still needed for Manyfold.

### Success Criteria

- No `netbox` VM, Salt key, database, role, Vault path, Zabbix host, PatchMon host or
  Tailscale node remains.
- `grep -rni netbox` in the Salt repo finds only PEPs and the changelog.
- Highstate on `docker` and `postgres` is clean afterwards.

## Implementation Plan

### Phase 1: Back up and stop

- Export the IP list. Disable the Zabbix host.
- `vzdump` the VM; `pg_dump` the database. Shut the VM down (don't delete) for a week.

### Phase 2: Remove

- Salt repo changes (one commit), apply on `docker` (Homepage) and `postgres`.
  **Before** dropping the database: `pillar/top.sls` gives `postgres` the
  `application.netbox` pillar, so a highstate there could recreate the database and
  role if the pillar is still in place.
- Drop the database and role on `postgres`; `salt-key -d netbox`; delete the VM.
- Remove the Zabbix and PatchMon hosts and the Tailscale node; delete the Vault paths.

### Phase 3: Notes

- Extract, then archive `netbox-deployment` to `90-archive/` (moved in Obsidian).

## Testing Strategy

- After Phase 1: nothing alerts; Homepage shows the tile as down (expected until Phase 2).
- After Phase 2: `salt docker state.apply test=True` and `salt postgres state.apply test=True`
  clean; `grep -rni netbox` as above.

Backout (within 30 days): restore the `vzdump`, restore the `pg_dump`, `git revert` the
Salt commit, re-accept the key. After that: the build is documented in the archived note.

## Documentation Requirements

- Update the vault notes that link to NetBox (homelab-tailscale-https,
  homelab-salt-fix, homelab-vm-provisioning-revival).

## Risks and Mitigation

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Something still reads NetBox | Breaks after shutdown | Low | Phase 1 shuts down for a week before deleting; only Homepage links to it |
| Dropping the wrong database | Data loss on `postgres` | Low | `pg_dump` first; drop by exact name |

## References

- PEP-HL-SLT-022 (hosts from the Salt mine), PEP-HL-SLT-011 and 021 (rejected)
- Vault: netbox-deployment, homelab-tailscale-https

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 0.1 | 2026-10-13 | Timo Vlot | Initial draft |
