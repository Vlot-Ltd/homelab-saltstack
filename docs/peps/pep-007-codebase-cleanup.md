# PEP-007: Codebase Cleanup

**PEP:** 007  
**Title:** Codebase Cleanup  
**Author:** Timo Vlot  
**Status:** Draft  
**Type:** Process  
**Created:** 2026-05-12  
**Updated:** 2026-05-12  
**Supersedes:** N/A  
**Superseded-By:** N/A  

## Abstract

The codebase contains dead files, an unfinished state with hardcoded placeholder credentials, and minor issues that add noise and confusion without serving any purpose. This PEP removes or completes them.

## Motivation

Dead code and placeholder values are a maintenance liability: they add confusion when reading the codebase, may be mistakenly applied, and in the case of `netbox/superuser.sls` would create a service account with a well-known default password if ever run. Cleaning these up reduces cognitive overhead and eliminates the risk of accidentally applying placeholder configuration.

**Issues addressed:**

1. **`salt/application/netbox/initold.sls`** — an old Docker-based NetBox implementation, completely superseded by the current `netbox/` state tree. Contains multiple hardcoded secrets. Dead code.
2. **`salt/application/netbox/webserver.sls`** — empty file (one line). Referenced in a commented-out include; serves no purpose.
3. **`salt/application/netbox/superuser.sls`** — contains hardcoded placeholder credentials (`[email protected]` / `yourpassword`). If this state is ever applied, it creates a NetBox superuser with a publicly known password.
4. **PostgreSQL maintenance: REINDEX on system database** — `salt/database/postgres/maintenance.sls` runs `REINDEX DATABASE postgres` on the PostgreSQL system database. This is unusual (the system database rarely needs reindexing), very slow on large instances, and locks the database. It should target application databases only.
5. **Plex SQLite operations on live database** — `salt/application/plex/maintenance.sls` performs SQLite3 operations (integrity checks, vacuum) without stopping the Plex service first, risking database corruption.
6. **Duplicate limits entries** — `salt/application/plex/maintenance.sls` appends to `/etc/security/limits.conf` without checking for existing entries, producing duplicates on repeated highstate runs.

## Specification

### Requirements

- Dead files are removed from the repository
- `netbox/superuser.sls` is either completed with proper credential management (from Vault) or removed
- Maintenance states are corrected to target the right databases and manage service state safely
- `/etc/security/limits.conf` management uses an idempotent approach

### Implementation Approach

**Cleanup 1 — Remove `initold.sls` and `webserver.sls`**

```bash
git rm salt/application/netbox/initold.sls
git rm salt/application/netbox/webserver.sls
```

Confirm neither is referenced in any include or top.sls entry.

**Cleanup 2 — Fix `netbox/superuser.sls`**

Option A: Complete it properly using Vault for credentials (coordinate with PEP-002):

```yaml
create_netbox_superuser:
  cmd.run:
    - name: >
        python3 /opt/netbox/netbox/manage.py shell -c
        "from django.contrib.auth.models import User;
        User.objects.filter(username='admin').exists() or
        User.objects.create_superuser('admin', '{{ pillar['netbox']['superuser_email'] }}', '{{ pillar['netbox']['superuser_password'] }}')"
    - unless: >
        python3 /opt/netbox/netbox/manage.py shell -c
        "from django.contrib.auth.models import User;
        exit(0 if User.objects.filter(username='admin').exists() else 1)"
    - runas: netbox
```

Option B: Remove the file if a superuser is created during initial NetBox setup via another mechanism.

Recommendation: Implement Option A only after PEP-002 has moved the superuser password to Vault. Until then, leave the file but add a guard so it does not run:

```jinja
{%- if false %}
# Disabled: requires PEP-002 and PEP-007 completion
{%- endif %}
```

**Cleanup 3 — Fix REINDEX target in `postgres/maintenance.sls`**

Change `REINDEX DATABASE postgres` to target only the application databases defined in pillar:

```jinja
{% for db in salt['pillar.get']('postgres:databases', []) %}
REINDEX DATABASE {{ db['name'] }};
{% endfor %}
```

Or remove the REINDEX step entirely — autovacuum handles index bloat incrementally and a full REINDEX is rarely needed outside of a specific corruption recovery scenario.

**Cleanup 4 — Stop Plex before SQLite operations**

In `plex/maintenance.sls`, wrap SQLite operations with service stop/start:

```yaml
stop_plex_for_maintenance:
  service.dead:
    - name: plexmediaserver
    - require_in:
      - cmd: plex_sqlite_vacuum

plex_sqlite_vacuum:
  cmd.run:
    - name: sqlite3 /var/lib/plexmediaserver/... "VACUUM;"
    - require:
      - service: stop_plex_for_maintenance

start_plex_after_maintenance:
  service.running:
    - name: plexmediaserver
    - require:
      - cmd: plex_sqlite_vacuum
```

**Cleanup 5 — Idempotent limits.conf**

Replace the append-based approach with a `file.line` or `file.blockreplace` state that only adds the entry if absent:

```yaml
plex_limits:
  file.blockreplace:
    - name: /etc/security/limits.conf
    - marker_start: "# BEGIN plex limits"
    - marker_end: "# END plex limits"
    - content: |
        plex soft nofile 65536
        plex hard nofile 65536
    - append_if_not_found: True
```

### Success Criteria

- `initold.sls` and `webserver.sls` no longer exist in the repository
- `netbox/superuser.sls` does not use placeholder credentials
- Running `postgres/maintenance.sls` does not touch the `postgres` system database
- Running `plex/maintenance.sls` stops Plex before any SQLite operation and restarts it after
- Running highstate twice does not add duplicate entries to `/etc/security/limits.conf`

## Implementation Plan

### Phase 1: Remove Dead Files

- `git rm` initold.sls and webserver.sls
- Search for any references to these files in includes or top.sls
- Commit

### Phase 2: Disable Superuser Placeholder

- Add a Jinja guard to `netbox/superuser.sls` preventing it from running until properly implemented
- Track proper implementation as a follow-up after PEP-002

### Phase 3: Fix Maintenance States

- Fix REINDEX target in postgres/maintenance.sls
- Add service stop/start around SQLite operations in plex/maintenance.sls
- Fix limits.conf to use `file.blockreplace`

## Claude Prompt Context

### Context for AI Assistance

```
You are helping implement PEP-007 for a homelab SaltStack project.
Goal: Clean up dead files and fix incorrect maintenance state behaviour.
Technology stack: SaltStack, PostgreSQL, Plex Media Server, SQLite3, Jinja2
Files to remove: salt/application/netbox/initold.sls, salt/application/netbox/webserver.sls
Files to fix:
  - salt/application/netbox/superuser.sls (placeholder credentials)
  - salt/database/postgres/maintenance.sls (REINDEX targets wrong database)
  - salt/application/plex/maintenance.sls (SQLite ops without service stop; duplicate limits.conf entries)
Constraint: Do not remove any state that is actively used by top.sls or referenced in an include
Current status: Draft - all issues still present
```

### Specific AI Tasks

- [ ] Provide `git rm` commands for dead files with verification that they are unreferenced
- [ ] Write a Jinja guard for `netbox/superuser.sls` disabling it until implemented
- [ ] Rewrite REINDEX block in `postgres/maintenance.sls` to target pillar-defined databases
- [ ] Rewrite `plex/maintenance.sls` SQLite section with service stop/start wrapping
- [ ] Rewrite limits.conf management using `file.blockreplace`

## Testing Strategy

- After removing files: `salt-call --local state.show_top` must not reference removed files
- After superuser guard: `salt <netbox-minion> state.apply application.netbox.superuser` must apply cleanly (no-op)
- After REINDEX fix: run maintenance state and confirm only application databases are touched (check postgres logs)
- After plex fix: run maintenance state and confirm `plexmediaserver` is stopped during SQLite step, restarted after
- After limits fix: run highstate twice and `grep -c plex /etc/security/limits.conf` returns 2 (not 4+)

## Documentation Requirements

- Add a comment in `postgres/maintenance.sls` explaining why `postgres` system database is excluded
- Add a comment in `plex/maintenance.sls` explaining the stop/start requirement for SQLite integrity

## Risks and Mitigation

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Removing initold.sls breaks an unreferenced but needed state | NetBox misconfigured | Low | Grep for references before deleting |
| Stopping Plex during maintenance causes noticeable outage | Family impact | Medium | Schedule maintenance cron during overnight hours (already at midnight) |
| Removing REINDEX on system DB leaves undetected index corruption | Slow queries on system tables | Very Low | System database is managed by Postgres itself; autovacuum handles it |

## References

- `salt/application/netbox/initold.sls` — to be removed
- `salt/application/netbox/webserver.sls` — to be removed
- `salt/application/netbox/superuser.sls` — to be fixed
- `salt/database/postgres/maintenance.sls` — REINDEX target fix
- `salt/application/plex/maintenance.sls` — SQLite and limits.conf fix
- PEP-002 — netbox superuser password should come from Vault

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 0.1 | 2026-05-12 | Timo Vlot | Initial draft from audit findings |
