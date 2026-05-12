# PEP-002: Migrate Hardcoded Secrets to HashiCorp Vault

**PEP:** 002  
**Title:** Migrate Hardcoded Secrets to HashiCorp Vault  
**Author:** Timo Vlot  
**Status:** Draft  
**Type:** Infrastructure  
**Created:** 2026-05-12  
**Updated:** 2026-05-12  
**Supersedes:** N/A  
**Superseded-By:** N/A  

## Abstract

Multiple pillar files contain plaintext credentials stored directly in the repository. This PEP replaces all hardcoded secrets with Vault references, using the `vault_secrets.sls` pattern that already exists in the codebase as the target model.

## Motivation

The following files currently store credentials in plaintext, meaning anyone with read access to the repo has access to all service passwords:

| File | Secret(s) |
|------|-----------|
| `pillar/application/grafana.sls` | Admin password, datasource passwords |
| `pillar/application/heimdall2.sls` | DB password, JWT secret, API key |
| `pillar/application/netbox.sls` | DB password, secret key, Redis passwords, superuser password |
| `pillar/application/zabbix.sls` | DB password |
| `pillar/application/linkwarden.sls` | DB password |
| `pillar/application/plex.sls` | Plex API token |
| `pillar/database/postgres.sls` | Monitor user password |
| `pillar/common/security.sls` | Heimdall2 JWT API key |
| `pillar/application/homepage.sls` | Base64-encoded Basic Auth header for Patchmon |

The codebase already uses Vault (`pillar/common/vault_secrets.sls`) for some secrets, proving the infrastructure is in place. This PEP extends that pattern consistently.

## Specification

### Requirements

- All service passwords, API tokens, and cryptographic secrets must be stored in Vault, not in pillar files
- Pillar files reference Vault paths via `salt['vault.read_secret']()` or the existing `vault_secrets.sls` lookup pattern
- No plaintext secret value may appear in any `.sls` file committed to the repository
- Vault paths follow a consistent naming convention: `secret/data/<service>/<key>`

### Implementation Approach

**Vault secret layout:**

```
secret/data/grafana/
  admin_password
  zabbix_datasource_password

secret/data/heimdall2/
  db_password
  jwt_secret
  api_key

secret/data/netbox/
  db_password
  secret_key
  redis_password
  redis_cache_password
  superuser_password

secret/data/zabbix/
  db_password

secret/data/linkwarden/
  db_password

secret/data/plex/
  api_token

secret/data/postgres/
  monitor_password

secret/data/security/
  heimdall2_api_key

secret/data/patchmon/
  basic_auth_header
```

**Pillar lookup pattern** (following `vault_secrets.sls`):

```yaml
grafana:
  admin_password: {{ salt['vault.read_secret']('secret/data/grafana', 'admin_password') }}
```

### Success Criteria

- `git grep -r 'P@ss\|password:\|api_key:\|secret_key:\|jwt' pillar/` returns no plaintext credential values
- All services continue to function after migration (validated by Zabbix alerting)
- Vault audit log shows credential reads on each highstate run

## Implementation Plan

### Phase 1: Vault Population

- Write all current plaintext secrets into Vault under the paths defined above
- Verify each secret is readable by the salt master's Vault token
- Document the Vault policy required for the salt master role

### Phase 2: Pillar Migration

Migrate each pillar file one service at a time, in this order (least-risk first):

1. `pillar/application/zabbix.sls`
2. `pillar/application/linkwarden.sls`
3. `pillar/database/postgres.sls`
4. `pillar/application/grafana.sls`
5. `pillar/application/netbox.sls`
6. `pillar/application/heimdall2.sls`
7. `pillar/application/plex.sls`
8. `pillar/common/security.sls`
9. `pillar/application/homepage.sls`

After each migration: run `salt <target> state.apply` and confirm the service is healthy.

### Phase 3: Validation and Rotation

- Rotate all secrets that were exposed in plaintext (assume repository is compromised)
- Confirm no secrets remain in git history via `git log -S <old_password>` for each rotated value
- If secrets appear in history, consider `git filter-repo` or accept the history is tainted and focus on rotation

## Claude Prompt Context

### Context for AI Assistance

```
You are helping implement PEP-002 for a homelab SaltStack project.
Goal: Replace hardcoded secrets in SaltStack pillar files with HashiCorp Vault lookups.
Technology stack: SaltStack, HashiCorp Vault (file backend, TLS currently disabled - see PEP-004), Python/Jinja2
Existing pattern: pillar/common/vault_secrets.sls uses salt['vault.read_secret']('secret/data/...', 'key')
Vault address: configured on the vault minion, accessible to salt master
Constraint: Must not break running services during migration - migrate one service at a time
Current status: Draft - secrets still in plaintext pillar files
```

### Specific AI Tasks

- [ ] Generate updated pillar file content for each service using Vault lookups
- [ ] Write Vault policy HCL granting salt master read access to `secret/data/*`
- [ ] Write a migration script to bulk-load current pillar secrets into Vault
- [ ] Generate validation commands to confirm each service works post-migration

## Testing Strategy

- After each pillar file migration, run `salt <minion> state.apply` for the affected service
- Confirm service health via Zabbix (zabbix.taile3eee.ts.net)
- Run `salt <minion> pillar.get <service>` to confirm Vault lookups resolve correctly
- Check salt master logs for Vault authentication errors

## Documentation Requirements

- Update `pillar/common/vault_secrets.sls` with comments explaining the lookup pattern
- Document the Vault path hierarchy in this PEP's revision history once finalised
- Add Vault policy file to repo under `salt/application/vault_policy.hcl`

## Risks and Mitigation

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Vault unavailable during highstate | Services fail to configure | Medium | Ensure Vault HA or accept dependency; document recovery |
| Salt master Vault token expires | All pillar lookups fail | Medium | Configure token renewal in Vault agent or use AppRole with lease |
| Secrets in git history remain accessible | Exposure continues | High | Rotate all credentials after migration |
| Migration breaks a running service | Service outage | Low | Migrate during maintenance window, one service at a time |

## References

- `pillar/common/vault_secrets.sls` — existing Vault lookup pattern to extend
- `salt/application/vault.sls` — Vault server state
- PEP-004 — Enable TLS on Vault (should be completed before this PEP in production)
- HashiCorp Vault KV v2 documentation

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 0.1 | 2026-05-12 | Timo Vlot | Initial draft from audit findings |
