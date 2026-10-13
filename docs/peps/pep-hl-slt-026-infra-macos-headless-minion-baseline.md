# PEP-HL-SLT-026: macOS headless minion baseline

**ID:** PEP-HL-SLT-026  
**Title:** macOS headless minion baseline  
**Author:** Timo Vlot  
**Status:** Draft  
**Type:** Infrastructure  
**Priority:** Medium  
**Created:** 2026-10-13  
**Updated:** 2026-10-13  
**Supersedes:** N/A  
**Superseded-By:** N/A  

## Abstract

A macOS baseline role so a headless Mac Mini is Salt-managed after day 1: power and sleep, SSH, Homebrew, Tailscale, Zabbix agent, update reporting.

## Motivation

A Mac Mini (Apple Silicon, macOS 26) is coming as the local LLM host, replacing `wopr`.
It will sit behind a monitor with no HDMI port free and no hub: no keyboard, screen or
reachable power button (on the M4 it is underneath the case) after day 1. Everything
after the first login has to come from Salt, or be reachable over SSH.

The repo has one macOS state, `os.mac.brew_update`, targeted at `os:MacOS`. It runs
`brew update && brew upgrade` as `timo` on every highstate, which the pillar schedule
runs every 30 minutes. On a model host that upgrades Ollama underneath running
models, unannounced. It has to go before the Mac Mini is a minion.

The manual day 1 steps (what Salt can't do on macOS without MDM) are in the vault note
`30-projects/mac-mini-model-host.md`. This PEP is everything after that.

## Specification

### Requirements

Targeting: a pillar flag `macos:headless: True` set for the Mac Mini's minion id only,
so the MacBook (if a minion) never gets power or SSH changes.

1. **Power, no physical access needed** (`pmset`, `systemsetup` via `cmd.run` with
   `unless` checks, or `module.run` on `power.*` where the module covers it):
   - restart after power failure on (`autorestart 1`): a smart plug becomes the power button
   - restart after a freeze on
   - system sleep, disk sleep and Power Nap off; display sleep allowed
   - no Wake-on-LAN: the box is Wi-Fi only (no cabling where it sits); not needed
     with sleep off
2. **SSH**: Remote Login is switched on by hand on day 1 (needs Full Disk Access to
   do from the CLI). Salt manages `/etc/ssh/sshd_config.d/100-homelab.conf`: keys
   only, no root login, and `~timo/.ssh/authorized_keys` from pillar. Reload via
   `launchctl kickstart -k system/com.openssh.sshd` on change.
3. **Homebrew**: Salt installs packages with `pkg.installed` (brew provider, runs as
   the brew owner). `brew_update` is replaced by: no `upgrade` in highstate; a
   pillar list of pinned formulae (`brew pin`); upgrades are a deliberate
   `salt <mac> state.apply os.mac.brew_upgrade`.
4. **Tailscale**: the open-source `tailscale` formula (`tailscaled` as a system
   LaunchDaemon, no GUI app, no system extension approval). Salt installs and keeps
   the daemon running. Joining the tailnet is a one-off by hand (`sudo tailscale up`,
   approve from another device), not an auth key in pillar.
5. **Zabbix agent**: Zabbix ships macOS packages for agent 1 (`zabbix_agentd`) only,
   not agent 2. `macpackage.installed` from the official arm64 OpenSSL `.pkg`
   (version and SHA256 in pillar, matching the server's 7.4 line); config
   `/usr/local/etc/zabbix/zabbix_agentd.conf` from a template; service
   `com.zabbix.zabbix_agentd` via `service.running`. PSK, if used, from Vault pillar.
6. **macOS updates**: on Apple Silicon `softwareupdate --install` needs the volume
   owner's password. Not automated. Salt reports pending updates
   (`softwareupdate.list_available`) into a file the Zabbix agent reads; installs are
   by hand over SSH (`sudo softwareupdate -i -a -R`), then the FileVault unlock if on.
7. **Hostname**: `ComputerName`, `HostName`, `LocalHostName` set from the minion id.

### Out of scope

- `common` failures on macOS: PEP-HL-SLT-025 (dependency, do first).
- Ollama: PEP-HL-SLT-027.
- Full Disk Access / privacy (TCC) grants: need MDM to automate. Manual, if needed.
- Screen Sharing: can't be switched on remotely without MDM; manual on day 1.

### Success Criteria

- After day 1 and key acceptance, one `state.highstate` brings the Mac Mini to the
  baseline with `Failed: 0`; a second run shows no changes.
- `pmset -g` shows `autorestart 1`, `sleep 0`, `disksleep 0`.
- Pulling the plug and restoring it brings the box back on the tailnet and in Salt
  (`salt <mac> test.ping`) over Wi-Fi, nobody logged in, without anyone touching it
  (with FileVault off; with it on, after an SSH unlock, which needs macOS 26.5+ on Wi-Fi).
- Zabbix shows the host with agent availability green and the pending-updates item.
- No highstate runs `brew upgrade`.

## Implementation Plan

### Phase 1: Retire brew_update

- Remove `os.mac.brew_update` from `top.sls`; add `os.mac.brew_upgrade` (manual only).
- Check which minions match `os:MacOS` today (`salt -G os:MacOS test.ping`).

### Phase 2: Power, hostname, SSH

- `salt/os/mac/power.sls`, `hostname.sls`, `ssh.sls`; `os/mac/init.sls` includes them
  when `macos:headless` is true.
- Test on the Mac Mini on day 2 with `test=True` while the KVM/keyboard is still
  attached, then for real. Plug-pull test.

### Phase 3: Homebrew and Tailscale

- `salt/os/mac/brew.sls` (package list, pins), `salt/application/tailscale/darwin.sls`.

### Phase 4: Zabbix agent and update reporting

- `salt/application/zabbix/agent_darwin.sls` plus pillar; host added on the server
  with a macOS-suitable template (check what 7.4 ships; Linux keys like
  `vfs.fs.*`, `system.cpu.load`, `proc.num` work on macOS, memory keys partly).

## Testing Strategy

- `test=True` first for each phase on the Mac Mini, while a keyboard and screen
  are still attached (day 2), so a broken SSH config can be fixed locally.
- SSH drop-in: `sshd -t` as a `check_cmd` before the file is replaced.
- Plug-pull test after Phase 2.
- Backout: `git revert <sha>` and push. On the Mac, `pmset restoredefaults`; remove
  `/etc/ssh/sshd_config.d/100-homelab.conf` and kickstart sshd; `brew uninstall
  tailscale`; for the Zabbix agent, unload the launchd job and remove the files
  listed by `pkgutil --files <id>` (id from `pkgutil --pkgs | grep -i zabbix`).

## Documentation Requirements

- Vault note `30-projects/mac-mini-model-host.md`: day 1 checklist, day 2 handover.
- README: `os/mac` states and the `macos:headless` flag.

## Risks and Mitigation

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Wi-Fi doesn't rejoin at the login window after a reboot | Box unreachable until someone logs in | Low | Plug-pull test with nobody logged in, on day 2 with the keyboard still attached |
| Bad sshd drop-in locks out SSH | Box unreachable; needs KVM | Medium | `check_cmd: sshd -t`; first apply on day 2 with keyboard attached |
| FileVault on, power cut | Box waits at pre-boot; services down until SSH unlock | High if on | Decide FileVault on day 1; macOS 26 allows SSH unlock on Apple Silicon (Remote Login must be on) |
| Zabbix pkg changes ID/paths between versions | Install state not idempotent | Low | Pin version and hash in pillar; `pkgutil --pkgs` check |
| Salt minion version ahead of master | Minion refuses or misbehaves | Low | Install the same major (3008) as the master |
| `brew` runs as root | brew refuses | Medium | `runas` the brew owner, as `brew_update` does today |

## References

- PEP-HL-SLT-018 (users and sudo, Linux VMs), 019 (Tailscale Services in Salt),
  025 (common on macOS), 027 (Ollama)
- Zabbix 7.4 manual: macOS agent installation from PKG
- Salt modules: `mac_power`, `mac_system`, `mac_service`, `mac_softwareupdate`,
  `mac_brew_pkg`, `macpackage`

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 0.1 | 2026-10-13 | Timo Vlot | Initial draft |
