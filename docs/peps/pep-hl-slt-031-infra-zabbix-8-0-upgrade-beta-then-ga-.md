# PEP-HL-SLT-031: Zabbix 8.0 upgrade (beta, then GA)

**ID:** PEP-HL-SLT-031  
**Title:** Zabbix 8.0 upgrade (beta, then GA)  
**Author:** Timo Vlot  
**Status:** Active  
**Type:** Infrastructure  
**Priority:** Medium  
**Created:** 2026-10-16  
**Updated:** 2026-10-17  
**Supersedes:** N/A  
**Superseded-By:** N/A  

## Abstract

Upgrade homelab Zabbix server and database schema from 7.4 to the 8.0 beta via Salt, then to 8.0 GA, with HashiCorp Vault integration; canary for the work upgrade in November 2026.

## Motivation

Homelab Zabbix runs 7.4.14 on `zabbix` (Ubuntu 24.04), with its database on the
shared `postgres` box (PostgreSQL 16.15, no TimescaleDB). Work upgrades to 8.0 in
November 2026. The homelab goes first, on the 8.0 beta, as the canary: it shows
what breaks (Grafana's Zabbix plugin, templates, config parameters) before it
matters at work.

The upgrade also brings in the Zabbix–HashiCorp Vault integration, which isn't
configured today. Its first consumer is a LiteLLM `/health` check that needs the
LiteLLM master key as a Vault secret macro.

Planning detail lives in the vault note `30-projects/homelab-zabbix-8-upgrade.md`.

## Specification

### Requirements

- `zabbix` runs Zabbix server and frontend 8.0 (beta first, then GA), with the
  `zabbix` database schema upgraded by the server on first start.
- `salt/application/zabbix/repo.sls` installs the 8.0 `zabbix-release` package, and
  `salt zabbix state.apply application.zabbix.server test=True` is clean afterwards.
- `zabbix_server.conf.jinja` holds only parameters valid in 8.0.
- Zabbix reads secrets from Vault using an AppRole, with a policy limited to the
  paths it needs. No new secrets in the repo or in pillar files.
- Nothing else on `postgres` (NetBox, Linkwarden, Heimdall2, Manyfold databases) is
  touched.
- Constraint: there is no second Zabbix server to rehearse on. The upgrade runs
  straight on the live pair, with a `pg_dump` and a VM snapshot as the backout.
- Constraint: templates shared with work stay built at 7.4 export format; 8.0
  exports won't import into work's 7.4.

### Implementation Approach

- **Repo:** point `repo.sls` at
  `https://repo.zabbix.com/zabbix/8.0/release/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_8.0+ubuntu24.04_all.deb`.
  The beta is published in the 8.0 repo as `zabbix-release 8.0-0.x`, so GA is
  expected to be a package upgrade from the same repo.
- **Package upgrade by hand in the window** (`apt install --only-upgrade`), not by
  Salt: `pkg.installed` doesn't upgrade installed packages, and the schema upgrade
  must not be interrupted.
- **Config:** checked 2026-10-16. All 36 parameters in `zabbix_server.conf.jinja`
  exist in the 8.0 server parameter list. 8.0 deprecates only
  `HistoryStorageURL`, `HistoryStorageTypes` and `HistoryStorageDateIndex` (replaced
  by `HistoryProvider`); none are in the template.
- **Vault:** 8.0 server parameters `Vault=HashiCorp`, `VaultURL`, `VaultPrefix`,
  `VaultAppRoleID`, `VaultAppSecretID` (AppRole, so no token to renew). Credentials
  come from pillar (Vault-backed), rendered into `zabbix_server.conf` `0600`.
- **Grafana Zabbix plugin:** it doesn't publish supported Zabbix versions. Accepted
  risk (Timo, 2026-10-16); the homelab result informs the work upgrade.

### Success Criteria

- `zabbix_server -V` reports 8.0, the frontend loads, and latest data has no gap
  beyond the maintenance window.
- `zabbix_server.log` shows the database upgrade completed with no errors.
- `test=True` on `zabbix` reports no changes after the Salt change is committed.
- Grafana's Zabbix panels show data.
- A Vault secret macro resolves in a test item, with no Vault errors in the log.
- After GA ships: `zabbix_server -V` reports the GA version.

## Implementation Plan

### Phase 1: Preparation (no downtime)

- Check how `pkg.installed` with `sources` behaves against the installed
  `zabbix-release 1:7.4-3`, without committing:
  `salt zabbix state.single pkg.installed name=zabbix-release sources='[{"zabbix-release": "<8.0 URL>"}]' test=True`.
  It must say it would install. If it reports "already installed", use `version:`
  or remove-then-install in `repo.sls`.
- Check `unattended-upgrades` on `zabbix` doesn't allow the Zabbix repo origin, so
  the 8.0 repo can't trigger an upgrade outside the window.
- Check free space on `postgres` for the dump and schema upgrade.
- Done 2026-10-16: release-package test passes (would install); unattended-upgrades
  allows Ubuntu origins only; `zabbix` DB 20 GB, 61 GB free on `postgres` `/`.
- Commit the `repo.sls` change only in Phase 2, after the packages are upgraded.

### Phase 2: Upgrade window

- Pause scheduled highstate on `zabbix` and `postgres`; stop `zabbix-server`.
- `pg_dump -Fc` the `zabbix` database on `postgres`, copy it off the box.
- Proxmox snapshot of the `zabbix` VM; back up `/etc/zabbix/`, the Apache Zabbix
  config and `/usr/share/zabbix/`.
- Install the 8.0 release package, `apt update`, `apt install --only-upgrade` the
  server packages, keeping Salt's config files.
- Start `zabbix-server`, wait for the schema upgrade to complete, restart Apache,
  check frontend and latest data.
- Commit the `repo.sls` change, `test=True`, unpause highstate.

- **Done 2026-10-17:** 8.0.0rc1 (`2:8.0.0~rc1-2`, from the `8.0/unstable` repo).
  Schema upgraded automatically by the server on start in about two minutes. All
  steps ran from the master via `cmd.run` (use `cmd='…'` when the command contains
  `=`). Old 7.4 repo file removed; `test=True` clean; schedule re-enabled.

### Phase 3: Vault integration

- Vault policy (read on Zabbix's paths only) and an AppRole for `zabbix`.
- Vault parameters in `zabbix_server.conf.jinja` from pillar; enable Vault secret
  macros in the frontend.
- Test with a Vault secret macro on a test item.

### Phase 4: Beta to GA (expected mid to late November 2026)

- Check the GA release notes for an upgrade path from the beta.
- Upgrade the packages from the same repo. If there's no supported path: restore
  the Phase 2 dump and upgrade 7.4 → 8.0 GA, or install GA fresh and import config.
- Keep the Phase 2 dump until GA is running.

## Testing Strategy

- Phase 1 `state.single ... test=True` result recorded before any commit.
- After Phase 2: `zabbix_server -V`, frontend login, latest data on three hosts,
  `zabbix_server.log` free of errors, Grafana Zabbix panels.
- `salt zabbix state.apply application.zabbix.server test=True` clean.
- Phase 3: a Vault secret macro resolves in a test item.

## Documentation Requirements

- Vault note `30-projects/homelab-zabbix-8-upgrade.md`: versions, outcome, anything
  that broke (feeds the work upgrade).
- `docs/VAULT_SALT_SETUP.md`: the Zabbix AppRole and policy.

## Risks and Mitigation

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Schema upgrade fails or is interrupted | High | Low | `pg_dump` of `zabbix` taken with the server stopped; restore plus VM snapshot revert |
| No supported path from beta to GA | Medium | Medium | Keep the 7.4 dump; restore and upgrade to GA, or reinstall and import |
| Grafana Zabbix plugin breaks on 8.0 | Medium | Low | No published 8.0 support (issue #2575 open), but 8.0 removes only write API methods the plugin doesn't use. Accepted; homelab is the canary for work. Check the Grafana API user's role keeps `api.access` (8.0 default changed to disabled) |
| `pkg.installed` with `sources` doesn't switch the release package | Low | Medium | Phase 1 `state.single` test before committing |
| 8.0 repo reached by unattended-upgrades outside the window | High | Low | Phase 1 check; commit `repo.sls` only after the window |
| Snapshot rollback of `postgres` hits other apps' databases | High | Low | Never snapshot-revert `postgres`; backout is the `zabbix` dump only |
| 8.0 template exports won't import into work's 7.4 | Low | High | Build shared templates at 7.4 |

## References

- PEP-HL-SLT-002, PEP-HL-SLT-008: Vault pillar integration (pattern for the AppRole)
- PEP-HL-SLT-029: Grafana Salt takeover (Grafana lives on `zabbix`)
- [Zabbix 8.0 upgrade procedure](https://www.zabbix.com/documentation/8.0/en/manual/installation/upgrade)
- [Zabbix 8.0 server parameters](https://www.zabbix.com/documentation/8.0/en/manual/appendix/config/zabbix_server)
- [Zabbix 8.0 HashiCorp configuration](https://www.zabbix.com/documentation/8.0/en/manual/security/secrets/hashicorp)

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 0.1 | 2026-10-16 | Timo Vlot | Initial draft |
| 0.2 | 2026-10-16 | Timo Vlot | Phase 1 checks done; Grafana plugin risk researched |
| 0.3 | 2026-10-17 | Timo Vlot | Phase 2 done: 8.0.0rc1 live |
