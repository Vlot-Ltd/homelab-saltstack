# PEP-008: Restore Vault Pillar Integration

**PEP:** 008  
**Title:** Restore Vault Pillar Integration  
**Author:** Timo Vlot  
**Status:** Testing  
**Type:** Infrastructure  
**Created:** 2026-05-12  
**Updated:** 2026-05-13  
**Supersedes:** N/A  
**Superseded-By:** N/A  

## Abstract

`salt['vault.read_secret']()` calls in `pillar/common/vault_secrets.sls` were breaking pillar compilation on all minions, causing highstate failures across the entire homelab. As a workaround the calls were replaced with `pillar.get()` stubs that silently return empty strings. This PEP diagnoses the root cause of the Vault lookup failure, fixes the Salt master Vault configuration, and restores proper secret resolution. The pillar-side changes are implemented and staged — only Salt master configuration and testing remain.

## Implementation Notes (2026-05-13)

The broken `vault_secrets.sls` has been deleted. Vault lookups are now inline in each service pillar file (see PEP-002 for the full set of changes staged). The path convention used is `salt/roles/<role>` and `salt/minions/<minion>` — no `secret/data/` prefix, using the Salt vault extension path format directly.

**What remains before this PEP is complete:**

1. **Salt master Vault runner must be correctly configured** — `/etc/salt/master.d/vault.conf` (or equivalent) must point at the Vault server with a valid token. This is not in the repository. Verify with:
   ```bash
   salt-run vault.read_secret salt/roles/db zabbix_password
   ```
   If this returns the password, the master config is working. If it errors, fix the runner config before testing pillar compilation.

2. **All required secrets must exist in Vault** at the paths defined in PEP-002's implementation notes. Verify each path with `vault kv get <path>` before running pillar tests.

3. **Test pillar compilation** — once steps 1 and 2 pass, confirm each minion resolves its secrets:
   ```bash
   salt '*' pillar.items
   ```
   No minion should error. Check for any `None` or empty string values where secrets are expected.

4. **Run highstate** on each affected minion and confirm services are healthy in Zabbix.

## Motivation

### What broke and when

The git history tells the story:

| Commit | What changed | Effect |
|--------|-------------|--------|
| `93d5e57` | First attempt: `vault.read_secret('secret/homepage', ...)` | KV v1 paths — wrong for KV v2 engine |
| `fdf458c` | Corrected to `vault.read_secret('secret/data/homepage', ...)` | Right paths, but lookups still failed |
| `e95485a` | "Revert vault_secrets.sls" — path change reverted (incorrectly) | Paths went back to wrong `secret/homepage` form |
| `efcc1e7` | Final: replaced all `vault.read_secret()` with `pillar.get()` | Secrets now silently return `''` |

The current state of `pillar/common/vault_secrets.sls`:

```yaml
homepage_secrets:
  tmdb_api_key: {{ pillar.get('tmdb_api_key', '') }}    # always ''
  steam_api_key: {{ pillar.get('steam_api_key', '') }}   # always ''
  steam_user_id: {{ pillar.get('steam_user_id', '') }}   # always ''

postgres_secrets:
  zabbix_password: {{ pillar.get('zabbix_password', '') }}  # always ''
  netbox_password: {{ pillar.get('netbox_password', '') }}  # always ''
```

Because `vault_secrets` is applied to **all minions** via `pillar/top.sls '*'`, a Vault lookup error during pillar compilation broke every host simultaneously. The workaround traded a loud failure for a silent one — services depending on these secrets are currently misconfigured with empty values.

### Impact of empty secrets

- Homepage widgets requiring `tmdb_api_key` or `steam_api_key` silently fail
- Zabbix and NetBox database connections using `zabbix_password`/`netbox_password` fail or use wrong credentials
- Any future expansion of `vault_secrets.sls` (per PEP-002) is blocked until Vault lookups work

### Likely root causes

The path correction (`secret/homepage` → `secret/data/homepage`) in commit `fdf458c` was correct for a KV v2 engine. The fact that it still failed after that correction points to one or more of:

1. **Salt master Vault runner not configured** — no `/etc/salt/master.d/vault.conf` (or equivalent) defining the Vault address, auth method, and token
2. **Vault token not issued or expired** — the token the Salt master uses to authenticate has expired or was never created
3. **Vault not initialized or sealed** — Vault is deployed but never initialized (`vault operator init`) or is sealed after a restart
4. **Salt `vault` module version mismatch** — the `salt['vault.read_secret']()` function signature changed between Salt versions; newer Salt uses `salt['vault.read_secret'](path, key)` only with certain `vault` runner configurations
5. **Secrets not written to Vault** — the KV paths (`secret/data/homepage`, `secret/data/postgres`) do not exist in Vault because no one wrote the secrets there

## Specification

### Requirements

- `salt['vault.read_secret']()` calls in pillar files must resolve correctly on all minions
- A Vault lookup failure must not break highstate for unrelated services — errors must be isolated
- The Salt master Vault runner must be configured and documented in this repo
- Secrets must exist in Vault at the correct KV v2 paths before pillar compilation references them

### Diagnosis Steps (run before implementing fixes)

**Step 1 — Confirm Vault is running and accessible:**

```bash
# From salt master
curl http://<vault-ip>:8200/v1/sys/health
# Expect: {"initialized":true,"sealed":false,...}
```

**Step 2 — Confirm Salt master Vault runner config exists:**

```bash
cat /etc/salt/master.d/vault.conf
# Expect: vault: url: http://...:8200 auth: method: token ...
```

**Step 3 — Confirm Vault token is valid:**

```bash
VAULT_ADDR=http://<vault-ip>:8200 VAULT_TOKEN=<salt-token> vault token lookup
# Expect: token details with non-expired TTL
```

**Step 4 — Confirm secrets exist at the correct paths:**

```bash
VAULT_ADDR=http://<vault-ip>:8200 VAULT_TOKEN=<salt-token> vault kv get secret/homepage
# Expect: keys tmdb_api_key, steam_api_key, steam_user_id
```

**Step 5 — Test Salt vault runner directly:**

```bash
salt-run vault.read_secret secret/data/homepage tmdb_api_key
# If this works, the pillar lookup will work
```

### Implementation Approach

**Fix A — Salt master Vault runner configuration**

Create `/etc/salt/master.d/vault.conf` on the Salt master with the correct structure. This file is not in the repo (it contains the master Vault token) but its expected format should be documented and managed:

```yaml
vault:
  url: http://<vault-ip>:8200
  auth:
    method: token
    token: <vault-token-for-salt-master>
  policies:
    - salt-master
  ttl: 3600
```

A Salt state to manage this file (without the token in the repo) should be added to `salt/application/vault.sls` or a new `salt/common/vault_client.sls`, reading the token from a separate secret or environment variable.

**Fix B — Write secrets to Vault at correct KV v2 paths**

The KV v2 engine requires the `data/` component in API paths but NOT in the CLI. The `vault.read_secret` Salt function uses the API path form. Confirm paths are correct:

```bash
# Write (CLI — no 'data/' prefix needed):
vault kv put secret/homepage tmdb_api_key=xxx steam_api_key=yyy steam_user_id=zzz
vault kv put secret/postgres zabbix_password=xxx netbox_password=yyy

# Salt reads using API path (with 'data/'):
salt['vault.read_secret']('secret/data/homepage', 'tmdb_api_key')
```

**Fix C — Restore `vault_secrets.sls` with correct paths and error handling**

```jinja
# pillar/common/vault_secrets.sls
homepage_secrets:
  tmdb_api_key: "{{ salt['vault.read_secret']('secret/data/homepage', 'tmdb_api_key') }}"
  steam_api_key: "{{ salt['vault.read_secret']('secret/data/homepage', 'steam_api_key') }}"
  steam_user_id: "{{ salt['vault.read_secret']('secret/data/homepage', 'steam_user_id') }}"

postgres_secrets:
  zabbix_password: "{{ salt['vault.read_secret']('secret/data/postgres', 'zabbix_password') }}"
  netbox_password: "{{ salt['vault.read_secret']('secret/data/postgres', 'netbox_password') }}"
```

**Fix D — Isolate Vault lookup failures**

Because `vault_secrets` is applied to all minions, a Vault outage currently would break the entire fleet. Add a Jinja try/except guard (Salt supports this via the `salt` execution module):

```jinja
{%- set _vault_ok = salt['vault.read_secret']('secret/data/homepage', 'tmdb_api_key') is not none -%}
{%- if not _vault_ok %}
  {%- do salt.log.warning('Vault unreachable — homepage secrets will be empty') %}
{%- endif %}
homepage_secrets:
  tmdb_api_key: "{{ salt['vault.read_secret']('secret/data/homepage', 'tmdb_api_key') or '' }}"
```

Or restructure so that `vault_secrets.sls` is only applied to minions that actually use the secrets (docker host for homepage, postgres host for database passwords) rather than all minions via `'*'`.

### Success Criteria

- `salt '*' pillar.get homepage_secrets` returns non-empty values for tmdb_api_key, steam_api_key, steam_user_id
- `salt '*' pillar.get postgres_secrets` returns non-empty values for zabbix_password, netbox_password
- Homepage Steam and TMDB widgets display data
- Zabbix and NetBox connect to their respective databases using the Vault-sourced passwords
- A Vault restart does not break highstate on unrelated minions

## Implementation Plan

### Phase 1: Diagnosis

Run the five diagnostic steps above on the Salt master to determine which root cause applies. Document the findings — the fix depends on the diagnosis.

Most likely finding based on git history: the Salt master Vault runner config is missing or has an expired token, AND the secrets were never written to Vault (both required).

### Phase 2: Salt Master Vault Runner Setup

- Create `/etc/salt/master.d/vault.conf` with correct Vault URL and a long-lived token
- Restart `salt-master` to pick up the new config
- Test with `salt-run vault.read_secret secret/data/homepage tmdb_api_key`

### Phase 3: Write Secrets to Vault

- Write all secrets referenced in `vault_secrets.sls` to Vault at the correct paths
- Confirm with `vault kv get secret/homepage` and `vault kv get secret/postgres`

### Phase 4: Restore vault_secrets.sls

- Revert the `pillar.get()` stubs back to `vault.read_secret()` calls with KV v2 paths (`secret/data/...`)
- Test pillar compilation: `salt '*' pillar.items`
- Confirm no highstate failures

### Phase 5: Isolate Vault Dependency

- Move `vault_secrets` out of `'*'` pillar target and into only the minions that use the secrets
- Or add error handling so a Vault outage degrades gracefully rather than breaking all highstates

## Claude Prompt Context

### Context for AI Assistance

```
You are helping implement PEP-008 for a homelab SaltStack project.
Goal: Fix broken Vault pillar lookups in pillar/common/vault_secrets.sls.
Technology stack: SaltStack, HashiCorp Vault (KV v2 engine, file backend, TLS disabled — see PEP-004)
Vault address: http://<vault-ip>:8200 (IP sourced from pillar hosts_entries)
Salt vault runner config location: /etc/salt/master.d/vault.conf (not in repo)
KV v2 path convention: vault kv put secret/homepage ... → read via salt['vault.read_secret']('secret/data/homepage', 'key')
Current broken state: vault_secrets.sls uses pillar.get() stubs that always return ''
Affected secrets: tmdb_api_key, steam_api_key, steam_user_id (homepage), zabbix_password, netbox_password (postgres)
vault_secrets is applied to ALL minions via pillar/top.sls '*' — fix must not break fleet on Vault outage
Current status: Draft - Vault lookups disabled, secrets are empty strings
```

### Specific AI Tasks

- [ ] Write the correct Salt master `/etc/salt/master.d/vault.conf` structure for token auth against KV v2
- [ ] Write a Salt state (`salt/common/vault_client.sls` or similar) that manages the master vault runner config without storing the token in the repo
- [ ] Provide the corrected `pillar/common/vault_secrets.sls` with proper KV v2 paths
- [ ] Suggest how to restructure the pillar top.sls so vault_secrets only targets minions that need it
- [ ] Provide Vault CLI commands to write the required secrets at the correct paths
- [ ] Write a diagnostic script to check all five root-cause conditions

## Testing Strategy

- `salt-run vault.read_secret secret/data/homepage tmdb_api_key` — must return the secret value
- `salt 'docker' pillar.get homepage_secrets:tmdb_api_key` — must return non-empty string
- `salt 'postgres' pillar.get postgres_secrets:zabbix_password` — must return non-empty string
- `salt '*' state.apply` — full highstate must succeed on all minions
- Stop Vault, run `salt '*' pillar.items` — must complete without hard failure (degraded gracefully)

## Documentation Requirements

- Document the Vault runner config format in a comment at the top of `vault_secrets.sls`
- Document the Vault token creation process (what policy, how to renew) in this PEP's BLOG once implemented
- Add a note to `salt/application/vault.sls` about the separate master-side runner config

## Risks and Mitigation

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Vault sealed after restart | All pillar lookups fail | High | Document unseal procedure; consider auto-unseal for homelab |
| Salt master Vault token expires | Pillar lookups fail silently | Medium | Use a long TTL (1 year) or periodic token renewal cron |
| Restoring vault.read_secret breaks fleet if Vault unreachable | All highstates fail | Medium | Move vault_secrets out of `'*'` target before restoring lookups |
| Secrets not yet written to Vault | Lookups return None/error | High | Phase 3 must complete before Phase 4 |

## References

- `pillar/common/vault_secrets.sls` — file to be fixed
- `pillar/top.sls` — controls which minions receive vault_secrets (needs scoping)
- `salt/application/vault.sls` — Vault server deployment state
- PEP-002 — broader secrets migration (this PEP unblocks PEP-002)
- PEP-004 — Vault TLS (complete before relying on Vault for production secrets)
- Salt docs: `salt.runners.vault`, `salt.modules.vault`
- HashiCorp Vault KV v2: path format `secret/data/<path>` for API, `secret/<path>` for CLI

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 0.1 | 2026-05-12 | Timo Vlot | Initial draft — diagnosed from git history and current file state |
