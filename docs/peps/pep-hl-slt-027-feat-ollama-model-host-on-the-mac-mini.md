# PEP-HL-SLT-027: Ollama model host on the Mac Mini

**ID:** PEP-HL-SLT-027  
**Title:** Ollama model host on the Mac Mini  
**Author:** Timo Vlot  
**Status:** Draft  
**Type:** Feature  
**Priority:** Medium  
**Created:** 2026-10-13  
**Updated:** 2026-10-13  
**Supersedes:** N/A  
**Superseded-By:** N/A  

## Abstract

Ollama on the Mac Mini as a Salt-managed launchd daemon, so it replaces wopr as the model host without a logged-in user.

## Motivation

Ollama runs on the Alienware (`wopr`), which sleeps nightly and isn't Salt-managed.
The Mac Mini replaces it (vault: `local-llm-alienware-build`, "Beyond the Alienware").
LiteLLM on `friday` routes the `local` tier to it; only its `api_base` changes.

The usual Mac install (Ollama.app, or `brew services start ollama`) runs Ollama as a
per-user LaunchAgent: it only runs while that user is logged in. A headless box with
no auto-login (auto-login and FileVault exclude each other) would have no Ollama after
a reboot. It has to run as a system LaunchDaemon, which Salt can own end to end.

## Specification

### Requirements

- Ollama from the Homebrew formula, pinned (`brew pin ollama`); upgrades only through
  `os.mac.brew_upgrade` (PEP-HL-SLT-026), never in a highstate.
- Runs as `/Library/LaunchDaemons/<label>.plist`, managed by Salt (`file.managed`
  plus `service.running`), as a non-admin service account, `KeepAlive` and `RunAtLoad`
  true. Starts at boot with nobody logged in.
- Environment from pillar: `OLLAMA_HOST=127.0.0.1:11434` (local only),
  `OLLAMA_MODELS` on a fixed path owned by the service account, `OLLAMA_KEEP_ALIVE`,
  `OLLAMA_FLASH_ATTENTION`, `OLLAMA_MAX_LOADED_MODELS`.
- HTTPS on the tailnet through a Tailscale Service (`svc:ollama`), the same pattern
  as `llm` on `friday` (PEP-HL-SLT-019); this closes "Ollama on `wopr`: plain HTTP" in
  the vault's `homelab-tailscale-https`.
- Model list in pillar, matching what `wopr` serves today; Salt pulls missing ones
  (`ollama pull` with an `unless` on `ollama list`). No removals by Salt.
- Optional: GPU wired-memory limit (`sysctl iogpu.wired_limit_mb`) from pillar, applied
  at boot by a LaunchDaemon, since the sysctl doesn't persist. Only if a model needs it.

### Out of scope

- LiteLLM: stays on `friday`. Its `api_base` change belongs to PEP-HL-SLT-014's
  config, done by hand until then.
- Retiring `wopr`.

### Success Criteria

- After a cold boot (plug pulled, nobody logs in), `curl -s https://ollama.<tailnet>/api/tags`
  from `friday` lists the pillar models.
- `ollama` is pinned: `brew list --pinned` includes it; two highstates in a row show
  no changes.
- LiteLLM `local` route answers through the Mac Mini; HA Assist still works.
- Zabbix: launchd job running, port 11434 listening, API answering.

## Implementation Plan

### Phase 1: Daemon

- `salt/application/ollama/` with `init.sls` (brew, pin, user, dirs, plist, service)
  and pillar `pillar/application/ollama.sls`.
- Apply; reboot with nobody logged in; check the API locally over SSH.

### Phase 2: Models and HTTPS

- Model list in pillar; first pull is large, so run it by hand with
  `state.apply application.ollama` and a long timeout rather than in a scheduled
  highstate.
- Tailscale Service `ollama`.

### Phase 3: Cut over

- Point LiteLLM `local` at the new name, check HA, leave `wopr` up for a week as
  fallback.

## Testing Strategy

- `test=True` first; `plutil -lint` on the plist as a `check_cmd`.
- Cold boot test with nobody logged in.
- Compare answers and tokens/s for one prompt on `wopr` and the Mac Mini.
- Backout: point LiteLLM back at `wopr` (it stays up during Phase 3). On the Mac:
  `launchctl bootout system/<label>`, remove the plist, `git revert <sha>`.

## Documentation Requirements

- Vault: `local-llm-alienware-build` (host change), `llm-routing-strategy`
  (`api_base`), `homelab-tailscale-https` (Ollama HTTPS done).

## Risks and Mitigation

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Model pull in a scheduled highstate | 30-minute schedule overlaps; disk fills | Medium | `maxrunning: 1` already; pulls only on explicit apply; free-space check first |
| Ollama binary path changes with brew | Daemon fails to start | Low | Plist points at `/opt/homebrew/opt/ollama/bin/ollama` (stable symlink) |
| Metal/GPU access as a non-login daemon | Slow CPU-only inference | Medium | Check tokens/s in Phase 1; fall back to running as `timo` if needed |
| Unified memory shared with macOS | Swap, slow responses | Medium | Model sizes from pillar sized to RAM; `OLLAMA_MAX_LOADED_MODELS=1` |

## References

- PEP-HL-SLT-014 (friday, LiteLLM), 019 (Tailscale Services), 026 (macOS baseline)
- Vault notes: `local-llm-alienware-build`, `llm-routing-strategy`, `homelab-tailscale-https`

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 0.1 | 2026-10-13 | Timo Vlot | Initial draft |
