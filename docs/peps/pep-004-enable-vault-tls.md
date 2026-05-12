# PEP-004: Enable TLS on HashiCorp Vault

**PEP:** 004  
**Title:** Enable TLS on HashiCorp Vault  
**Author:** Timo Vlot  
**Status:** Draft  
**Type:** Infrastructure  
**Created:** 2026-05-12  
**Updated:** 2026-05-12  
**Supersedes:** N/A  
**Superseded-By:** N/A  

## Abstract

`salt/application/vault.sls` deploys Vault with `tls_disable = true`, meaning all traffic between the Salt master, minions, and Vault travels in plaintext. This PEP enables TLS using a self-signed CA, eliminating the plaintext credential exposure that currently occurs on every highstate run.

## Motivation

With TLS disabled, every Vault token, secret lookup, and authentication handshake is visible in plaintext on the network. This is particularly significant because PEP-002 will route all service credentials through Vault — once that migration is complete, a single packet capture would expose all service passwords.

The current config in `salt/application/vault.sls`:

```hcl
tls_disable = true
```

Even in a homelab context on a Tailscale network, Tailscale provides encryption at the network layer but does not protect against local sniffing on the Vault host itself, and `tls_disable = true` is a bad habit to carry into any production-adjacent workflow.

## Specification

### Requirements

- Vault must serve HTTPS on port 8200 (default)
- TLS certificate is managed by Salt and renewed automatically before expiry
- Salt master must trust the CA used to sign the Vault certificate
- All existing Vault client configuration (Salt's `vault` runner config) must be updated to use `https://`
- `tls_disable = false` (or the line removed entirely, as false is the default)

### Implementation Approach

**Option A: Self-signed CA via Salt's `tls` module (recommended)**

Salt has a built-in `tls` execution module that can generate a CA and sign certificates, requiring no external PKI:

1. Generate a CA keypair on the Salt master
2. Issue a server certificate for the Vault minion's hostname/IP
3. Distribute the CA cert to all minions so they trust Vault
4. Configure Vault to use the certificate

**Option B: Tailscale HTTPS certificates**

Tailscale provides `tailscale cert` for nodes on the tailnet, issuing certificates signed by Let's Encrypt via the Tailscale CA. This avoids managing a private CA entirely.

Recommendation: **Option B** if the Vault node has a stable Tailscale hostname (e.g. `vault.taile3eee.ts.net`). Tailscale certs auto-renew and are already trusted by the Tailscale CA. Otherwise use Option A.

**vault.hcl changes:**

```hcl
listener "tcp" {
  address       = "0.0.0.0:8200"
  tls_cert_file = "/opt/vault/tls/vault.crt"
  tls_key_file  = "/opt/vault/tls/vault.key"
}
```

**Salt master `/etc/salt/master.d/vault.conf` update:**

```yaml
vault:
  url: https://vault.taile3eee.ts.net:8200
  ...
```

### Success Criteria

- `curl https://vault.taile3eee.ts.net:8200/v1/sys/health` returns 200 without `-k` flag
- `salt '*' pillar.get grafana:admin_password` (after PEP-002) resolves correctly via HTTPS
- Vault audit log shows no plaintext connections

## Implementation Plan

### Phase 1: Certificate Provisioning

- Decide on Option A (Salt TLS module) or Option B (Tailscale cert)
- If Option A: run `salt <master> tls.create_ca vault` and issue a server cert
- If Option B: run `tailscale cert` on the Vault node and confirm cert path
- Store cert/key paths in pillar for use by the vault.sls template

### Phase 2: State Update

- Update `salt/application/vault.sls` to:
  - Manage cert/key files at `/opt/vault/tls/`
  - Set correct ownership (`vault:vault`, mode `0640` for key)
  - Render `vault.hcl` with TLS listener config
  - Remove `tls_disable = true`
  - Add `watch` on cert files to restart Vault on renewal
- Update Salt master vault runner config to use `https://`

### Phase 3: Rollout

- Apply updated state to Vault minion
- Confirm Vault unseals and is healthy post-restart
- Run a test highstate on one minion to confirm Vault lookups work over TLS
- Roll out to all minions

## Claude Prompt Context

### Context for AI Assistance

```
You are helping implement PEP-004 for a homelab SaltStack project.
Goal: Enable TLS on HashiCorp Vault by updating salt/application/vault.sls.
Technology stack: SaltStack, HashiCorp Vault (file backend), Tailscale (tailnet: taile3eee.ts.net)
Current vault.hcl has: tls_disable = true in the listener block
Vault minion is on Tailscale; its Tailscale hostname is resolvable as vault.taile3eee.ts.net
Salt master vault runner config is at /etc/salt/master.d/vault.conf (or equivalent)
Constraint: Vault must remain available during transition; plan for sealed state post-restart
Current status: Draft - TLS not yet enabled
```

### Specific AI Tasks

- [ ] Update `salt/application/vault.sls` to manage cert files and render TLS-enabled `vault.hcl`
- [ ] Write a Jinja template for `vault.hcl` with TLS listener
- [ ] Generate the Salt state to run `tailscale cert` and place cert/key in `/opt/vault/tls/`
- [ ] Update Salt master vault runner configuration for HTTPS endpoint

## Testing Strategy

- After applying: `curl -v https://<vault-host>:8200/v1/sys/health` — expect 200, valid cert
- `curl http://<vault-host>:8200/v1/sys/health` — expect connection refused or redirect
- Run `salt '*' test.ping` to confirm minions can still reach master (no config broken)
- Run `salt <minion> pillar.items` and confirm Vault-backed pillars resolve

## Documentation Requirements

- Document the cert renewal process (Tailscale auto-renews; Salt TLS requires manual or cron-based renewal)
- Add a note to `salt/application/vault.sls` explaining the cert source

## Risks and Mitigation

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Vault restart requires unseal | Vault unavailable until manually unsealed | High | Document unseal procedure; run during low-activity window |
| Salt master cannot reach Vault over HTTPS | All Vault-backed pillars fail | Medium | Test with `curl` before running highstate on all minions |
| Tailscale cert hostname mismatch | TLS handshake fails | Low | Use the exact Tailscale FQDN in the cert and vault.conf |
| Certificate expiry not monitored | Vault goes down unexpectedly | Medium | Add Zabbix check for cert expiry (>30 days warning) |

## References

- `salt/application/vault.sls` — file to be modified
- PEP-002 — Migrate Secrets to Vault (depends on this PEP for secure operation)
- HashiCorp Vault TLS configuration documentation
- Tailscale HTTPS certificates: `tailscale cert --help`

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 0.1 | 2026-05-12 | Timo Vlot | Initial draft from audit findings |
