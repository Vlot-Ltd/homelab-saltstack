# PEP-HL-SLT-024: Salt manages Salt with salt-formula

**ID:** PEP-HL-SLT-024  
**Title:** Salt manages Salt with salt-formula  
**Author:** Timo Vlot  
**Status:** Draft  
**Type:** Infrastructure  
**Priority:** Medium  
**Created:** 2026-10-13  
**Updated:** 2026-10-13  
**Supersedes:** N/A  
**Superseded-By:** N/A  

## Abstract

Bring in the upstream salt-formula (pinned, via gitfs) so Salt manages the master's and minions' own config from pillar, replacing the hand-copied /etc/salt/master.d files.

## Motivation

The master's config is hand-managed: `gitfs.conf` and `pillar.conf` (PEP-HL-SLT-010)
and `vault.conf` (PEP-HL-SLT-008) are copied from `conf/master.d/` in this repo to
`/etc/salt/master.d/` by hand, and `/etc/salt/master` still carries the insecure
`rest_cherrypy`/`testuser` block (PEP-HL-SLT-009). Minion config isn't managed at all.
Work already uses the upstream `saltstack-formulas/salt-formula` for this (its docs are
mirrored in the vault). With gitfs live, the homelab can pull it the same way.

Not for the Salt mine: the formula's own pillar example says `mine_functions` belong
at the top level of pillar (no config file change, no minion restart). PEP-HL-SLT-022
does that without the formula.

## Specification

### Requirements

- The formula is a second gitfs remote, pinned to a release tag (not `master`):
  `https://github.com/saltstack-formulas/salt-formula.git` with `base: <tag>`.
- Master config (`salt:master:` pillar) reproduces today's `master.d` exactly:
  gitfs, git_pillar plus Vault `ext_pillar` order, `peer_run`, `autosign_grains_dir`,
  `vault` settings.
- The AppRole `role_id`/`secret_id` come from Vault-backed pillar, never plain pillar
  in git.
- Minion config (`salt:minion:` pillar) for all minions: at least `master`, and
  whatever the minions carry by hand today (inventory first).
- Package install and version stay as they are at first (`install_packages: false`)
  until the formula's 3008 onedir support is confirmed. The example pins 3006.
- `saltext-vault` and `pygit2` (salt-pip) stay in `salt/application/salt-master.sls`;
  the formula doesn't manage Salt extensions.

### Out of scope

- The Salt API and SaltGUI: PEP-HL-SLT-009 decides what goes into the master config
  for those; this PEP only provides the mechanism.
- The Salt mine (PEP-HL-SLT-022).

### Success Criteria

- `salt salt state.apply salt.master test=True` shows no changes against the live,
  hand-made config. The formula takes over without a diff.
- A change to the master config is a pillar commit plus a state apply; no file is
  copied by hand.
- No AppRole credential in git (`git grep -i secret_id` finds nothing).

## Implementation Plan

### Phase 1: Inventory and pin

- Diff the live `/etc/salt/master`, `/etc/salt/master.d/*` and one minion's
  `/etc/salt/minion*` against the repo copies.
- Pick the formula release; check its 3008 onedir and Broadcom repo handling.
- Add the gitfs remote; `salt-run fileserver.file_list | grep '^salt/'`.

### Phase 2: Master

- Write `salt:master:` pillar; `test=True` on `salt` until it shows no changes.
- Apply; restart; repeat the GitFS checks (file list, pillar on all minions, a push
  picked up without `git pull`).

### Phase 3: Minions

- `salt:minion:` pillar; one minion `test=True`, then apply, then all.

## Testing Strategy

- `test=True` before every apply; aim for no changes on first takeover.
- After the master apply: the PEP-HL-SLT-010 checks (no master errors in the journal,
  identical pillar on every minion, `docker` test run unchanged).

Backout: before Phase 2, `tar czf /root/salt-conf-pre-formula.tgz /etc/salt/master
/etc/salt/master.d`; restore it and `systemctl restart salt-master`, then `git revert`.
Minions: restore a `/etc/salt/minion.d` backup taken in Phase 3 with `salt '*' cmd.run`.

## Documentation Requirements

- Update `conf/`: becomes the formula's pillar, or is removed once the formula owns
  the files (decide in Phase 2).

## Risks and Mitigation

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Bad render of master config | Salt master down; no fleet management | Medium | `test=True` until no diff; tarball backup; fix on the box with the backout |
| `ext_pillar` order changes | Vault lookups using `{pillar[roles]}` fail | Medium | Compare pillar on all minions before/after, as in PEP-HL-SLT-010 |
| AppRole secret ends up in git | Credential exposure | Low | Vault-backed pillar only; `git grep` check before push |
| Formula lags 3008 | Wrong package repo or version | Medium | `install_packages: false` until verified |

## References

- PEP-HL-SLT-008 (Vault pillar), 009 (Salt API, master config), 010 (gitfs), 022 (mine)
- `saltstack-formulas/salt-formula` (docs and pillar example mirrored in the vault)

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 0.1 | 2026-10-13 | Timo Vlot | Initial draft |
