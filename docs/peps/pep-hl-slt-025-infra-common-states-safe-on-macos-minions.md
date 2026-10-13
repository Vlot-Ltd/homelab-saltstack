# PEP-HL-SLT-025: common states safe on macOS minions

**ID:** PEP-HL-SLT-025  
**Title:** common states safe on macOS minions  
**Author:** Timo Vlot  
**Status:** Draft  
**Type:** Infrastructure  
**Priority:** High  
**Created:** 2026-10-13  
**Updated:** 2026-10-13  
**Supersedes:** N/A  
**Superseded-By:** N/A  

## Abstract

Make the states every minion gets (common, its pillar) OS-aware so a macOS minion can run a highstate cleanly; today they assume systemd, apt and group root.

## Motivation

`salt/top.sls` gives `common` to `'*'`, and `pillar/top.sls` gives every minion
`common.timesync`, `common.security`, `application.zabbixagent` and `application.docker`.
`common` was written for Ubuntu and Raspberry Pi OS only:

- `common.timesync` installs `systemd-timesyncd`, removes `ntp`/`chrony`, and runs
  `systemctl` and `timedatectl`. None of that exists on macOS; every state fails.
- `common.mine_functions` writes `/etc/salt/minion.d/mine_functions.conf` with
  `group: root`. macOS has no `root` group (it is `wheel`, gid 0), so it fails.
- `common.hosts` uses `host.present`; that works on macOS (`/etc/hosts`), but needs
  checking against the PEP-HL-SLT-022 rewrite.
- `common.schedule` (highstate every 30 minutes) works on macOS as is.

A Mac Mini is due as the local LLM host (PEP-HL-SLT-026, 027). With today's code, its
first highstate fails before anything Mac-specific runs, and the scheduled highstate
keeps failing every 30 minutes. That is noise in the job cache and hides real failures.

## Specification

### Requirements

- A highstate on a `kernel:Darwin` minion runs `common` with no failed states.
- No change in behaviour on Linux minions: `test=True` shows no changes on every
  Linux minion before and after.
- OS branching by grain (`kernel`), in one place per state, not scattered `if`s.
- macOS time sync: timezone `Europe/London` via `timezone.system` (supported by
  `mac_timezone`), network time on via `timezone` / `systemsetup -setusingnetworktime on`.
  No `ntp`/`chrony` handling on macOS.
- Root group from a map: `root` on Linux, `wheel` on Darwin.

### Implementation Approach

- `salt/common/map.jinja` with a `root_group` and per-kernel defaults; `mine_functions`
  and anything else with `group: root` imports it.
- Split `common/timesync.sls` into `timesync/linux.sls` (today's file, unchanged) and
  `timesync/darwin.sls`; `timesync/init.sls` includes the one matching
  `grains['kernel']`. Keeps the Linux file byte-identical, so the Linux diff is empty.
- Pillar: leave `common.timesync` pillar shared; the macOS state only reads
  `timezone` and the NTP server list.
- `common.security` pillar and `application.docker` pillar are data only and harmless
  on macOS; leave them for now, note in PEP-HL-SLT-026 if the Mac gets its own.

### Out of scope

- Anything Mac-specific beyond what `common` needs: PEP-HL-SLT-026.
- `common.hosts` redesign: PEP-HL-SLT-022. This PEP only checks it runs on macOS.

### Success Criteria

- `salt -G 'kernel:Linux' state.apply common test=True` shows no changes before and
  after the merge.
- `salt <mac> state.apply common` returns `Failed: 0`.
- `salt <mac> state.highstate` returns `Failed: 0` (given PEP-HL-SLT-026 Phase 1 or
  only `common` targeted).

## Implementation Plan

### Phase 1: Root group map

- Add `salt/common/map.jinja`; use it in `mine_functions.sls`.
- `test=True` on all Linux minions: expect no changes.

### Phase 2: Split timesync

- Move today's `timesync.sls` to `timesync/linux.sls` unchanged; add `init.sls` and
  `darwin.sls`.
- `test=True` on all Linux minions: expect no changes. Then the Mac.

### Phase 3: Check the Mac

- First highstate on the Mac Mini (or the MacBook, if it is a minion) with `test=True`;
  fix whatever else fails in `common`.

## Testing Strategy

- `salt-call --local state.show_sls common` on a Linux minion before and after:
  rendered output identical.
- Staggered: one Linux minion (`docker`) first, then `'*'`.
- Backout: `git revert <sha>` and push; gitfs picks it up. Nothing on the Linux
  minions changes, so nothing to undo there.

## Documentation Requirements

- Note in the README states section that `common` runs on Linux and macOS, and that
  new `common` states must use the map for OS-specific values.

## Risks and Mitigation

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Linux timesync behaviour changes by accident | Clock drift on VMs; Vault/TLS errors | Low | File moved unchanged; `test=True` on all Linux minions shows no changes |
| State ID collisions after the split | Render failure on every minion | Low | `state.show_sls` on one Linux minion before pushing |
| macOS `timezone.system` needs Full Disk Access | Timezone state fails | Low | Set by hand on day 1 if so; note in PEP-HL-SLT-026 |

## References

- PEP-HL-SLT-022 (hosts from the mine), 026 (macOS baseline), 027 (Ollama on the Mac Mini)
- Salt `mac_timezone` and `timezone` state module docs

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 0.1 | 2026-10-13 | Timo Vlot | Initial draft |
