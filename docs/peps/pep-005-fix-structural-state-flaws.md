# PEP-005: Fix Structural State Flaws

**PEP:** 005  
**Title:** Fix Structural State Flaws  
**Author:** Timo Vlot  
**Status:** Draft  
**Type:** Feature  
**Created:** 2026-05-12  
**Updated:** 2026-05-12  
**Supersedes:** N/A  
**Superseded-By:** N/A  

## Abstract

Several Salt states contain hard errors that will cause highstate runs to fail or silently misconfigure hosts: a broken include reference, a literal placeholder IP in the hosts file, malformed YAML, and a call to a binary that is never deployed. This PEP fixes all four issues.

## Motivation

These are not style issues — they are defects that produce incorrect or broken infrastructure:

1. **`salt/application/netbox/init.sls` includes `.redis`** — no such state exists, so any netbox highstate fails immediately with `Include Error`.
2. **`salt/common/hosts.sls` sets `docker_host_ip: '100.x.x.x'`** — this literal string ends up in `/etc/hosts` on every managed host, making the docker host unreachable by name.
3. **`salt/application/netbox/config.sls` has malformed YAML** (lines 17-18) — incorrect indentation around the `upgrade.sh` call causes a parse error on state load.
4. **`salt/os/linux/linux_patch.sls` calls `/usr/local/bin/patchmon-agent`** — this binary is not deployed by any state in the repository; the call fails silently or with an error on every patched host.

## Specification

### Requirements

- All four issues must be corrected without changing intended behaviour
- Changes must be tested by running the affected states on their target minions
- No new dependencies introduced without a corresponding state to manage them

### Implementation Approach

**Fix 1 — Broken `.redis` include in `netbox/init.sls`**

The `salt/application/netbox/prereqs.sls` already installs Redis. The `.redis` include was either a leftover from an earlier design or intended to be `prereqs`. Remove the broken include:

```yaml
# Remove this line:
- .redis
# The prereqs state already handles Redis installation
```

If a dedicated redis state is actually wanted, create `salt/application/netbox/redis.sls` as a thin wrapper around `prereqs` (or as an alias include).

**Fix 2 — Placeholder IP in `common/hosts.sls`**

The variable `docker_host_ip` should be sourced from pillar. The docker host's Tailscale IP is already defined in `pillar/application/docker.sls` (`tailscale_ip: 100.73.13.74`). Update the hosts state to read from pillar:

```jinja
{%- set docker_host_ip = salt['pillar.get']('docker:tailscale_ip', '') -%}
```

If the pillar key is absent (non-docker hosts), skip the docker host entry rather than writing the placeholder.

**Fix 3 — Malformed YAML in `netbox/config.sls`**

Correct the indentation at lines 17-18 so that the `cmd.run` state is properly nested under its state ID. The exact fix requires reading the surrounding context to determine the intended structure — likely the `upgrade.sh` call should be a `cmd.run` state with correct 2-space indentation under its ID.

**Fix 4 — Missing `patchmon-agent` binary**

Two options:
- **Option A**: Remove the `patchmon-agent report` call from `linux_patch.sls` and replace with a comment noting it is not yet implemented
- **Option B**: Create `salt/application/patchmon.sls` that installs the patchmon-agent binary and add it to the appropriate top.sls entry

For now, implement Option A (remove the call) to unblock patching. Track Option B as a future enhancement.

### Success Criteria

- `salt <netbox-minion> state.apply application.netbox` does not produce an `Include Error`
- `/etc/hosts` on all managed hosts contains a valid IP for the docker host, not `100.x.x.x`
- `salt <netbox-minion> state.apply application.netbox.config` does not produce a YAML parse error
- `salt '*' state.apply os.linux.linux_patch` completes without a "command not found" error for patchmon-agent

## Implementation Plan

### Phase 1: Fix the Two Parse/Load Errors (Fixes 1 and 3)

These cause immediate state load failures and should be fixed first:
- Remove `.redis` include from `netbox/init.sls`
- Fix YAML indentation in `netbox/config.sls`
- Validate with `salt-call --local state.show_sls application.netbox` (dry parse check)

### Phase 2: Fix the Placeholder IP (Fix 2)

- Update `salt/common/hosts.sls` to read docker host IP from pillar
- Confirm pillar key path is correct for all target minions
- Apply to a test minion and inspect `/etc/hosts`

### Phase 3: Remove the Missing Binary Call (Fix 4)

- Comment out or remove the `patchmon-agent report` line in `linux_patch.sls`
- Add a `# TODO: pep-XXX patchmon-agent not yet deployed` comment
- Apply patching state to confirm it completes cleanly

## Claude Prompt Context

### Context for AI Assistance

```
You are helping implement PEP-005 for a homelab SaltStack project.
Goal: Fix four structural defects in Salt state files.
Technology stack: SaltStack, Jinja2
Files to modify:
  - salt/application/netbox/init.sls (remove broken .redis include)
  - salt/common/hosts.sls (replace placeholder '100.x.x.x' with pillar lookup)
  - salt/application/netbox/config.sls (fix YAML indentation at lines 17-18)
  - salt/os/linux/linux_patch.sls (remove call to undeployed patchmon-agent binary)
Pillar key for docker host IP: pillar.get('docker:tailscale_ip')
Constraint: Do not change intended behaviour, only fix the structural errors
Current status: Draft - all four defects still present
```

### Specific AI Tasks

- [ ] Provide corrected `salt/application/netbox/init.sls` without `.redis` include
- [ ] Provide corrected `salt/common/hosts.sls` with pillar-sourced docker_host_ip
- [ ] Provide corrected `salt/application/netbox/config.sls` with fixed indentation
- [ ] Provide corrected `salt/os/linux/linux_patch.sls` without patchmon-agent call

## Testing Strategy

- `salt-call --local state.show_sls application.netbox` — must not produce Include Error
- `salt-call --local state.show_sls application.netbox.config` — must not produce YAML parse error  
- Apply hosts state to a minion and `grep docker /etc/hosts` — must show valid IP
- Apply linux_patch state and confirm exit 0 with no command-not-found error

## Documentation Requirements

- Add a comment in `hosts.sls` explaining the pillar key used for docker host IP
- Add a TODO comment in `linux_patch.sls` referencing a future patchmon deployment PEP

## Risks and Mitigation

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Removing `.redis` include breaks netbox dependency | Redis not installed before netbox | Low | Verify `prereqs.sls` already installs Redis |
| Pillar key for docker IP absent on some minions | `/etc/hosts` missing docker entry | Medium | Guard with `if docker_host_ip` before writing the entry |
| Indentation fix changes behaviour of config.sls | Unexpected state applied to netbox | Low | Review full context of lines 15-25 before editing |

## References

- `salt/application/netbox/init.sls` — fix broken include
- `salt/common/hosts.sls` — fix placeholder IP
- `salt/application/netbox/config.sls` — fix malformed YAML
- `salt/os/linux/linux_patch.sls` — remove undeployed binary reference

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 0.1 | 2026-05-12 | Timo Vlot | Initial draft from audit findings |
