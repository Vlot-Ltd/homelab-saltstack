# PEP-HL-SLT-020: Docker compose restart handlers: in-place recreate, no implicit latest pulls

**ID:** PEP-HL-SLT-020  
**Title:** Docker compose restart handlers: in-place recreate, no implicit latest pulls  
**Author:** Timo Vlot  
**Status:** Draft  
**Type:** Bug  
**Priority:** Medium  
**Created:** 2026-10-13  
**Updated:** 2026-10-13  
**Supersedes:** N/A  
**Superseded-By:** N/A  

## Abstract

Docker app restart handlers take the whole stack down (docker compose down && up) on config change, and some pull :latest as a side effect; replace with in-place recreate and pinned images.

## Motivation

Found 2026-10-13 while checking the gitfs move (PEP-HL-SLT-010) on `docker`. Each
Docker app state restarts its stack through a `cmd.run` handler with `onchanges` on
its config files. The handlers use `docker compose down && ... up -d`, which:

- Takes every container in the stack down, even when only one file changed. Compose
  already recreates just the changed services on `up -d`.
- In three states, runs `docker pull <image>:latest` as part of the restart, so a
  config change also silently upgrades the app to whatever is newest. App versions
  change without a commit, and a bad upstream release lands during an unrelated change.
- Homepage uses `up -d --build`, which only makes sense if its compose file has a
  `build:` section.

The handlers only fire on config changes (`onchanges`), so this isn't a restart on
every highstate. The `docker` test run currently lists the Homepage handler as
"would change" because Homepage's `services.yaml`, `settings.yaml` and `widgets.yaml`
are genuinely pending (including `bc2ba4c`).

## Specification

### Affected states

| State | Handler | Command now |
|---|---|---|
| `salt/application/homepage/init.sls:141` | `restart-homepage-on-config-change` | `docker compose down && docker compose up -d --build` |
| `salt/application/linkwarden.sls:65` | `restart-linkwarden` | `down && docker pull ghcr.io/linkwarden/linkwarden:latest && up -d` |
| `salt/application/fing.sls:52` | `restart-fing` | `down && docker pull fing/fing-agent:latest && up -d` |
| `salt/application/heimdall2/init.sls:88` | `heimdall2_restart` | `docker compose pull && docker compose up -d`, `watch` on compose, `.env` and nginx config. Missed in the first survey, found 2026-10-16 (PEP-HL-SLT-030) |
| `salt/application/tailnet-service.sls:47` | `restart-{{ service_name }}` | `down && docker compose pull && up -d` |
| `salt/application/tailscale-docker.sls:55` | `restart-tailscale-docker` | `down && up -d`. Being removed by PEP-HL-SLT-019; skip |
| `salt/application/netbox/initold.sls:112` | (old Docker NetBox) | Not in any top file; leave for PEP-HL-SLT-007 cleanup |

### Requirements

- A config change recreates only the containers whose definition changed:
  `docker compose up -d` (plus `--force-recreate <service>` only where a bind-mounted
  config file needs a restart that compose can't see, such as Homepage's YAML).
- No implicit image pulls in restart handlers. Image versions are pinned in the
  compose file (or pillar), and an upgrade is a commit that changes the pin.
- `--build` only where the compose file has a `build:` section.
- Behaviour on an unchanged highstate stays as now: no handler fires.

### Out of scope

- Unguarded `cmd.run` status checks (`docker ps ... && echo RUNNING`) and the
  `/var/cache/salt/minion/check-*` file pattern: PEP-HL-SLT-006.
- Replacing `cmd.run` with `docker_container`/compose state modules.

### Success Criteria

- A changed config file on `docker` restarts only that app's affected container;
  `docker ps` shows the other containers' uptime unchanged.
- No `docker pull` or `compose pull` in any restart handler; `grep -rn 'pull' salt/application`
  finds only deliberate, version-pinned pulls.
- A highstate with no changes reports no handler as run.

## Implementation Plan

### Phase 1: Homepage

- Check whether `/docker/homepage/docker-compose.yml` has a `build:` section; drop
  `--build` if not.
- Replace the handler with `docker compose up -d --force-recreate homepage` (config is
  bind-mounted YAML, so compose won't see the change itself).
- Pin the Homepage image tag.

### Phase 2: Linkwarden, fing, tailnet-service macro

- Pin image tags in the compose templates (current running versions from
  `docker inspect`, so nothing changes on first apply).
- Handlers become `docker compose up -d`.

### Progress

- **2026-10-16: handlers rewritten** for homepage, heimdall2, linkwarden, fing,
  webdriver, tailscale-docker and the tailnet-service macro. Pattern:
  `start-<app>` runs `docker compose up -d` unless every service in the project is
  running (`docker compose ps --status running` counted against
  `docker compose config --services`). `recreate-<app>` runs `up -d` on compose or
  `.env` changes. Bind-mounted config changes restart only the affected container
  (`homepage`, heimdall2's `nginx`). No `down`, no `pull`, no `--build`. That also
  covers PEP-HL-SLT-006 Fix 2 (the check-file pattern is gone).
- Before the rewrite, every container was checked to run from its own
  `/docker/<app>` project (`docker inspect` compose labels), so `up -d` adopts
  them rather than duplicating. Linkwarden runs as `linkwarden-linkwarden-1`, but
  the compose file names it `linkwarden`. Its data mount matches
  (`/docker/linkwarden/data`), so a converge recreates and renames it, with data
  intact.
- **Still open: Phase 2 pins.** Images stay `:latest`, but nothing pulls, so a
  recreate uses the local image.

## Testing Strategy

- `salt docker state.apply application.<app> test=True` before and after: only the
  intended handler and file changes listed.
- Change one harmless config value, apply, and confirm with `docker ps` that only that
  app's container restarted.
- Second apply with no changes: no handler fires.

Backout: `git revert` this PEP's commits; the old handlers come back on the next apply.

## Documentation Requirements

- Comment in each state on why `--force-recreate` is (or isn't) used.
- Upgrade procedure for a pinned app: bump the tag, commit, apply.

## Risks and Mitigation

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Pinned tag differs from what's running | App up/downgrades on first apply | Medium | Take tags from `docker inspect` on `docker` before pinning |
| `up -d` doesn't pick up a bind-mounted config change | Stale config until manual restart | Medium | `--force-recreate <service>` where config is bind-mounted |
| Pins go stale | Missed security fixes | Medium | Upgrades tracked like other package pins (PatchMon doesn't cover containers) |

## References

- PEP-HL-SLT-006 (state quality, unguarded `cmd.run`), PEP-HL-SLT-007 (cleanup),
  PEP-HL-SLT-010 (where this was found), PEP-HL-SLT-019 (removes `tailscale-docker`)
- Docker Compose `up` reference: recreates only changed services unless
  `--force-recreate`

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 0.1 | 2026-10-13 | Timo Vlot | Initial draft |
