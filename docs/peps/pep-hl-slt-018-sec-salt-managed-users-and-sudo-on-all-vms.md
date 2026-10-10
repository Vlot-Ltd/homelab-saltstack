# PEP-HL-SLT-018: Salt-managed users and sudo on all VMs

**ID:** PEP-HL-SLT-018  
**Title:** Salt-managed users and sudo on all VMs  
**Author:** Timo Vlot  
**Status:** Draft  
**Type:** Security  
**Priority:** Medium  
**Created:** 2026-10-10  
**Updated:** 2026-10-10  
**Supersedes:** N/A  
**Superseded-By:** N/A  

## Abstract

Replace the shared `proxmox` account baked into every VM by the Proxmox template with Salt-managed named users and SSH keys, and manage sudo from Salt instead of the template's defaults.

## Motivation

State on 2026-10-10:

- Every VM built from the Proxmox template has the same `proxmox` user, with sudo (password required). It's the login for people and for tools, including Claude Code SSH sessions from the Mac.
- Salt manages no human users. The only user states are service accounts (`netbox` in `application/netbox/prereqs.sls`) and `docker` group membership for `root` and `proxmox` (`application/docker.sls`), which makes `proxmox` root-equivalent on `docker`.
- `friday` also has a `vault` user (the vault's own write access and the Claude Code OAuth token), kept deliberately separate from `proxmox`.
- One shared account on every box means no per-person or per-tool audit trail, and a leaked key or password opens every VM.

## Specification

### Requirements

- Named accounts from pillar via a `common.users` state (`user.present`, `ssh_auth.present`), applied to every Linux minion
- sudo from Salt: drop-in files under `/etc/sudoers.d/`, written with `check_cmd: /usr/sbin/visudo -c -f` so a bad file is never installed
- Separate accounts for automation and AI tools (Claude Code, later JARVIS), with narrower sudo than the human admin account. See the vault note `jarvis-access-model`.
- No secrets in pillar: public keys only; any password hashes come from Vault
- Lock-out protection: the new account is proven to log in and sudo before `proxmox` is touched
- The Proxmox template stops depending on `proxmox` (or keeps it only as a locked break-glass account)

### Implementation Approach

To decide in this PEP:

- Account names (human admin; automation; Claude Code)
- sudo for the human account: password or `NOPASSWD`
- sudo for tool accounts: command allowlists per role, or none
- What happens to `proxmox`: removed, or locked as break-glass (console only)
- SSH keys as `authorized_keys` from pillar, or short-lived certificates from Vault's SSH secrets engine (also fits the JARVIS access model)

### Success Criteria

- `salt '*' user.info <admin>` returns the account on every Linux minion
- SSH as the new account works everywhere; `sudo -l` shows exactly the intended rules
- `proxmox` is removed or locked everywhere, and nothing (states, scripts, docs) still logs in as it
- `visudo -c` passes on every minion

## Implementation Plan

### Phase 1: design

1. Answer the decisions above; write the pillar layout

### Phase 2: pilot

1. Apply to one low-risk VM, keeping a root console open in Proxmox
2. Log in and sudo as each new account; then lock `proxmox` on that VM only

### Phase 3: staggered rollout

1. Small groups of minions, then `*`, checking login after each
2. `docker` group: switch `application/docker.sls` from `proxmox` to the new admin account

### Phase 4: template

1. Update the Proxmox template / cloud-init so new VMs don't get `proxmox`

## Testing Strategy

`test=True` first on each group; after each apply, a fresh SSH login and `sudo -l` as each new account before moving on.

## Documentation Requirements

Update vault notes that say "as `proxmox`" (e.g. `llm-routing-strategy`, `jarvis-project-overview`) and the homelab Salt docs.

## Risks and Mitigation

- Lock-out: pilot one VM with a Proxmox console open; never remove `proxmox` in the same apply that creates the new account.
- Broken sudoers: `check_cmd` with `visudo` on every drop-in.
- Scripts and services that run as `proxmox` (e.g. LiteLLM on `friday`): find them before removing the account.

**Backout:** the `proxmox` account stays until the last phase; reverting the commit and re-applying restores the previous state. If locked out, log in via the Proxmox console as root.

## References

- Vault: `30-projects/jarvis/jarvis-access-model.md`
- Vault: `30-projects/jarvis/jarvis-project-overview.md` → "Security boundary"
- PEP-HL-SLT-009 (master hardening; SaltGUI eauth user)

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 0.1 | 2026-10-10 | Timo Vlot | Initial draft |
