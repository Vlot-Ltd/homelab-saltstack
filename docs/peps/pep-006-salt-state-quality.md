# PEP-006: Salt State Quality Improvements

**PEP:** 006  
**Title:** Salt State Quality Improvements  
**Author:** Timo Vlot  
**Status:** Draft  
**Type:** Feature  
**Created:** 2026-05-12  
**Updated:** 2026-05-12  
**Supersedes:** N/A  
**Superseded-By:** N/A  

## Abstract

Several Salt states have operational quality issues that cause silent failures, missed restarts, or unnecessary noise on every highstate run: missing `require`/`watch` directives mean config changes don't trigger service restarts; fragile grep-on-cache-file patterns for service status checks break unpredictably; and `salt/common/debug.sls` writes debug output to `/tmp` unconditionally in production.

## Motivation

These issues don't produce immediate failures but cause incorrect behaviour over time:

- **Missing `watch` directives**: Grafana's datasource config file is managed but Grafana is never restarted when it changes. Vault's service has no `require` chain from its config file. Config drift goes unnoticed until a manual restart.
- **Fragile status checks**: `fing.sls`, `linkwarden.sls`, and `tailscale-docker.sls` determine whether to restart a container by grepping a file at `/var/cache/salt/minion/check-<service>`. If this file is stale, missing, or corrupted, the service either never restarts or always restarts — both are wrong.
- **Unconditional debug output**: `salt/common/debug.sls` is included via `salt/common/init.sls` and runs on every host on every highstate, writing JSON files to `/tmp`. This is development scaffolding that should not run in production.
- **Inline Vault reads in state files**: `tailscale-docker.sls` and `homepage/init.sls` call `salt['vault.read_secret']()` directly in state Jinja. This works but duplicates the secret-fetching concern that should live in pillar, making it harder to audit where secrets are consumed.

## Specification

### Requirements

- Config file changes for Grafana and Vault must trigger a service restart via `watch`
- Service status checks for Docker-managed services must use `docker inspect` or similar, not grep on cache files
- `debug.sls` must be gated behind a pillar flag so it does not run unless explicitly enabled
- Inline Vault reads in state files should be replaced with pillar lookups (coordinated with PEP-002)

### Implementation Approach

**Fix 1 — Missing `watch` in `grafana/init.sls`**

The datasource configuration file state must have a corresponding `watch_in` or the service state must declare a `watch` on the file:

```yaml
grafana_datasources:
  file.managed:
    - name: /etc/grafana/provisioning/datasources/datasources.yaml
    - ...
    - watch_in:
      - service: grafana-server
```

Similarly for Vault — the `vault.hcl` file state should trigger a restart:

```yaml
vault_config:
  file.managed:
    - name: /etc/vault.d/vault.hcl
    - ...
    - watch_in:
      - service: vault
```

**Fix 2 — Fragile cache-file status checks**

Replace patterns like:

```bash
onlyif: grep -q running /var/cache/salt/minion/check-fing
```

With `docker inspect` which is authoritative:

```yaml
restart_fing:
  cmd.run:
    - name: docker compose -f /docker/fing/docker-compose.yml restart
    - onlyif: docker inspect --format '{{ "{{" }}.State.Running{{ "}}" }}' fing-agent | grep -q true
```

Or, better, use Salt's `docker_container` state module which manages the full container lifecycle declaratively and requires no custom status checks.

**Fix 3 — Gate `debug.sls` behind a pillar flag**

Wrap the entire `salt/common/debug.sls` content:

```jinja
{%- if salt['pillar.get']('debug:enabled', False) %}
# ... existing debug states ...
{%- endif %}
```

And add to `pillar/common/` a `debug.sls` with `debug: enabled: false` (defaulting to off). To enable on a specific minion, set `debug: enabled: true` in that minion's pillar.

**Fix 4 — Move inline Vault reads to pillar**

This is tracked primarily by PEP-002 but the state files affected are:
- `salt/application/tailscale-docker.sls`
- `salt/application/homepage/init.sls`

Once PEP-002 is implemented, these inline calls should be replaced with `{{ pillar['tailscale']['auth_key'] }}` etc.

### Success Criteria

- Editing Grafana's datasource config and running highstate causes `grafana-server` to restart (check via `systemctl status grafana-server` timestamp)
- Editing `vault.hcl` and running highstate causes Vault to restart
- A fresh minion with no cache files applies `fing.sls` without error
- Running highstate on any host does not write files to `/tmp` unless `debug: enabled: true` is in that host's pillar

## Implementation Plan

### Phase 1: Add Missing watch Directives (Low Risk)

- `salt/application/grafana/init.sls`: add `watch_in` to datasource file state
- `salt/application/vault.sls`: add `watch_in` to vault.hcl file state
- Verify by editing the config file, running highstate, and checking service restart

### Phase 2: Gate debug.sls

- Wrap `salt/common/debug.sls` in a pillar flag check
- Add `pillar/common/debug.sls` with `debug: enabled: false`
- Add `debug` to `pillar/top.sls` common includes
- Run highstate on a host and confirm no `/tmp/salt-*` files are created

### Phase 3: Fix Fragile Status Checks

- Update `fing.sls`, `linkwarden.sls`, `tailscale-docker.sls` to use `docker inspect` for status
- Alternatively, evaluate replacing the entire start/restart pattern with `docker_container.running` module states
- Test by stopping a container manually and running highstate — confirm it is restarted

### Phase 4: Remove Inline Vault Reads (Coordinate with PEP-002)

- Once PEP-002 establishes Vault-backed pillar keys, update `tailscale-docker.sls` and `homepage/init.sls` to use pillar lookups
- This phase is blocked on PEP-002 completion

## Claude Prompt Context

### Context for AI Assistance

```
You are helping implement PEP-006 for a homelab SaltStack project.
Goal: Fix Salt state quality issues — missing watch directives, fragile service checks, unconditional debug output.
Technology stack: SaltStack, Docker, Jinja2, Grafana, HashiCorp Vault
Files to modify:
  - salt/application/grafana/init.sls (add watch_in to datasource file state)
  - salt/application/vault.sls (add watch_in to vault.hcl file state)
  - salt/common/debug.sls (gate behind pillar flag)
  - salt/application/fing.sls, linkwarden.sls, tailscale-docker.sls (fix status checks)
Constraint: Do not change service behaviour, only add missing restart triggers and fix status checks
Current status: Draft - issues still present
```

### Specific AI Tasks

- [ ] Add `watch_in` directives to grafana/init.sls and vault.sls
- [ ] Wrap debug.sls content in a pillar flag Jinja guard
- [ ] Replace grep-on-cache-file patterns with `docker inspect` checks in fing.sls, linkwarden.sls, tailscale-docker.sls
- [ ] Write the pillar structure for `debug: enabled: false`

## Testing Strategy

- Grafana watch: edit datasource file → run highstate → `systemctl status grafana-server` shows recent restart
- Vault watch: edit vault.hcl → run highstate → check Vault service restart timestamp
- Debug gate: run highstate on a host without `debug: enabled: true` → `ls /tmp/salt-*` returns empty
- Status check: `docker stop fing-agent` → run highstate → container is running again

## Documentation Requirements

- Add a comment in `debug.sls` explaining how to enable it per-host via pillar
- Document the `watch_in` pattern in the BLOG for this PEP

## Risks and Mitigation

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Adding `watch` to Grafana causes unexpected restart | Brief Grafana outage | Low | Apply during maintenance window; Grafana restarts in seconds |
| Adding `watch` to Vault causes restart requiring unseal | Vault unavailable until manually unsealed | High | Complete PEP-004 (TLS) first; document unseal procedure |
| Replacing cache-file checks breaks start logic for a service | Container not started when it should be | Medium | Test on each service individually before rolling out |

## References

- `salt/application/grafana/init.sls` — missing watch directive
- `salt/application/vault.sls` — missing watch directive  
- `salt/common/debug.sls` — unconditional debug output
- `salt/application/fing.sls`, `salt/application/linkwarden.sls`, `salt/application/tailscale-docker.sls` — fragile status checks
- PEP-002 — inline Vault reads will be resolved as part of secrets migration

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 0.1 | 2026-05-12 | Timo Vlot | Initial draft from audit findings |
