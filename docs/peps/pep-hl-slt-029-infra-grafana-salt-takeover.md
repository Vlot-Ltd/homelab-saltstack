# PEP-HL-SLT-029: Grafana Salt takeover

**ID:** PEP-HL-SLT-029  
**Title:** Grafana Salt takeover  
**Author:** Timo Vlot  
**Status:** Draft  
**Type:** Infrastructure  
**Priority:** Medium  
**Created:** 2026-10-17  
**Updated:** 2026-10-17  
**Supersedes:** N/A  
**Superseded-By:** N/A  

## Abstract

Bring the live Grafana on zabbix under Salt without losing its settings, datasources or dashboards, and fix the never-applied application.grafana state first.

## Motivation

Grafana runs on `zabbix` (apt package `grafana`, service `grafana-server`), but no
highstate manages it. `salt/application/grafana/init.sls` exists, written in the
early "untested" commits, and has never been in `salt/top.sls`. Found 2026-10-17
while adding the Prometheus datasource for PEP-HL-SLT-028.

Applying that state as it is would damage the live Grafana:

- **`grafana.ini` is replaced wholesale** by a `file.managed` with `contents:` that
  holds only `[security] admin_user/admin_password`. Every other setting on the
  host is lost (server, auth, SMTP, plugins).
- **The datasource template** (`/etc/grafana/provisioning/datasources/datasources.yaml`)
  assumes every datasource has `secureJsonData.password_key` and a `jsonData` map,
  so a datasource without a password fails to render. It also drops `isDefault`,
  `trends`, `trendsFrom`, `trendsRange`, `cacheTTL`, `timeout` and
  `directDbConnection` that the pillar sets for the Zabbix datasource.
- **`grafana-cli-check`** runs `grafana-cli plugins list-remote` (a network call)
  on every apply, with no guard. It always reports a change.
- **`grafana-repo`** uses the old `packages.grafana.com` repo and `apt-key`-era
  keyring handling. Grafana's current repo is `apt.grafana.com`.

The observability work (PEP-HL-SLT-028, PEP-HL-SLT-015) wants dashboards and
datasources provisioned from git. That needs a Grafana state that can be applied
safely.

Until then, the Prometheus datasource lives in a standalone state,
`application.grafana.datasource-prometheus` (PEP-HL-SLT-028 Phase 3), which only
adds its own provisioning file.

## Specification

### Requirements

- **Inventory first, no changes:** Grafana version, the live `grafana.ini`
  (non-default lines only), the datasources and dashboards that exist in Grafana's
  database (UI-created) versus provisioned, the installed plugins, and the
  database type (SQLite at `/var/lib/grafana/grafana.db` unless configured
  otherwise).
- **`grafana.ini` managed by setting, not by file:** `ini.options_present` for the
  keys Salt owns (security from Vault pillar, plus whatever the inventory shows
  matters). Everything else in the file stays as it is.
- **Datasources:** one provisioning file per datasource, rendered from pillar with
  optional fields, so a datasource without a password renders. The Zabbix
  datasource keeps all its `jsonData`. UI-created datasources are either moved into
  pillar or left alone. Provisioning one with the same name takes over the UI copy,
  so that's a deliberate per-datasource choice.
- **Dashboards:** a file provider (`/etc/grafana/provisioning/dashboards/`)
  pointing at a git-managed directory, so dashboards from the observability work
  are committed JSON (`allowUiUpdates: false` for those).
- **Plugins:** `alexanderzobnin-zabbix-app` installed with an `unless` guard; the
  unguarded `list-remote` check removed.
- **Repo:** `apt.grafana.com` with the current keyring method. The package version
  pinned in pillar, upgraded by a commit.
- **Secrets:** admin password and datasource passwords from Vault pillar only
  (already the pattern via `*_key` names).

### Out of scope

- Moving Grafana off `zabbix` or into Docker. It stays a native package.
- Grafana alerting (`grafana-alerting-project` in the vault).
- Rebuilding existing dashboards. They're exported as they are.

### Implementation Approach

1. Inventory by hand (read-only commands, Phase 0), plus a backup of
   `/etc/grafana/` and `/var/lib/grafana/grafana.db`.
2. Rewrite `application.grafana` against that inventory, splitting it into
   `repo`, `install`, `config` (ini options), `datasources`, `dashboards` and
   `plugins`, so each can be applied and tested alone.
3. `test=True` must show **no change to anything that exists today** except the
   intended additions. Iterate until it does.
4. Apply. Then add `application.grafana` to the `zabbix` top. The standalone
   `datasource-prometheus` state folds into the new `datasources` part.

### Success Criteria

- `salt 'zabbix' state.apply application.grafana test=True` on an unchanged host
  reports zero changes.
- Every datasource that worked before still passes its Grafana test, and the Zabbix
  datasource still uses trends and the direct DB connection.
- Existing dashboards still load. Dashboards from git appear in their folder.
- `grafana.ini` differs from the backup only in the keys Salt owns.

## Implementation Plan

### Phase 0: Inventory and backup (read-only)

- `grafana-server -v`; `grep -vE '^\s*(;|#|$)' /etc/grafana/grafana.ini`;
  `ls -l /etc/grafana/provisioning/*/`; `grafana-cli plugins ls`.
- Datasources and dashboards from the API (admin login), saved to files.
- `tar czf /root/grafana-backup-<date>.tgz /etc/grafana /var/lib/grafana/grafana.db`.

### Phase 1: Safe state

- Rewrite and split the state. Iterate on `test=True` until only the intended
  changes show.

### Phase 2: Apply and top

- Apply, check the success criteria, add to `salt/top.sls`, and retire the
  standalone datasource state.

### Phase 3: Dashboards from git

- Dashboard provider and directory, ready for the observability dashboards
  (Claude Code, Bambu).

## Testing Strategy

- `test=True` before every apply, comparing against the Phase 0 inventory.
- After apply: datasource tests in the UI, open three existing dashboards, and
  `diff` the live `grafana.ini` against the backup.
- Backout: restore `/etc/grafana` and `grafana.db` from the Phase 0 tarball,
  `systemctl restart grafana-server`, and `git revert` the state commits.

## Documentation Requirements

- Vault: a Grafana runbook under `20-areas/monitoring/` (where config lives, what
  Salt owns, how to add a datasource or dashboard). `observability-redesign` already
  sketches `salt/grafana/provisioning.sls`, so reconcile with it.

## Risks and Mitigation

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Someone applies the current `application.grafana` before this lands | `grafana.ini` wiped, Zabbix datasource loses trends and direct DB | Low | Comment at the top of `init.sls` saying not to apply it; it stays out of the top |
| A provisioned datasource takes over a UI one with the same name | Settings changed or lost | Medium | Inventory first; decide per datasource; backup |
| Repo switch pulls a newer Grafana | Unplanned upgrade | Medium | Version pinned in pillar at the current version |
| Grafana DB not SQLite, or not where expected | Backup misses it | Low | Phase 0 reads `[database]` from `grafana.ini` first |

## References

- PEP-HL-SLT-028 (Prometheus, Phase 3 standalone datasource)
- PEP-HL-SLT-015 (Loki datasource, next)
- PEP-HL-SLT-017 (Homebox takeover, the same "inventory, back up, adopt" shape)
- Vault: `observability-redesign` (proposed Grafana provisioning), `homelab-telemetry-claude-bambu`

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 0.1 | 2026-10-17 | Timo Vlot | Initial draft |
