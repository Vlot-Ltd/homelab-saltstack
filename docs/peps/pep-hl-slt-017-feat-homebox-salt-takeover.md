# PEP-HL-SLT-017: Homebox Salt takeover

**ID:** PEP-HL-SLT-017  
**Title:** Homebox Salt takeover  
**Author:** Timo Vlot  
**Status:** Draft  
**Type:** Feature  
**Priority:** Low  
**Created:** 2026-10-10  
**Updated:** 2026-10-16  
**Supersedes:** N/A  
**Superseded-By:** N/A  

## Abstract

Homebox runs in Docker on docker but isn't managed by Salt, and where its compose/config lives is unknown. Find it, bring it under a Salt state, keep the data volumes, and give the Homepage widget credentials (currently 401, none in the template).

## Motivation

Homebox (home inventory) is one of the containers on `docker` that no Salt state
manages. A rebuild of `docker` from Salt would lose it, and nothing in git says how
it's configured.

Found 2026-10-16 with `docker inspect homebox`:

| What | Value |
|---|---|
| Started by | **Portainer**, stack ID 2. Compose labels: project `homebox`, working dir `/data/compose/2/v1`, file `/data/compose/2/v1/docker-compose.yml`. That's a path inside Portainer's own `/data` volume, not on the host |
| Image | `ghcr.io/sysadminsmedia/homebox:latest`, running **v0.20.2** (image `sha256:98f90e77b4e4…`), created about 15 months ago |
| Data | Named volume `homebox_homebox-data` → `/data` in the container. SQLite database and attachments |
| Ports | Host 3100 → container 7745 |
| Env (names only) | `HBOX_WEB_MAX_UPLOAD_SIZE`, `HBOX_LOG_LEVEL`, `HBOX_LOG_FORMAT`, `HBOX_MODE`, `HBOX_STORAGE_CONN_STRING`, `HBOX_STORAGE_PREFIX_PATH`, `HBOX_DATABASE_SQLITE_PATH` (plus `PATH`). None look like secrets; the values are read in Phase 0 |

The Homepage widget for Homebox returns 401. The widget needs Homebox credentials,
and the template has none.

## Specification

### Requirements

- `salt/application/homebox.sls` writes `/docker/homebox/docker-compose.yml` with:
  - compose project name `homebox` and service/container name `homebox`, so the
    existing container is recognised rather than duplicated
  - image pinned to `v0.20.2`, the running version, so the first apply changes
    nothing (PEP-HL-SLT-020: no `:latest`, no implicit pulls)
  - the existing volume declared `external: true` with
    `name: homebox_homebox-data`, so compose never creates or removes it
  - port and env values from pillar (`pillar/application/homebox.sls`), copied from
    the Portainer stack's compose file
- Handlers per PEP-HL-SLT-020: `docker compose up -d` on change, no `down`/`up`.
- Homepage widget credentials: a dedicated Homebox user for the widget, its
  password in Vault, read into the Homepage template through Vault pillar.
- Portainer no longer owns the stack. Remove it from Portainer only after Salt
  manages the container, and without removing volumes.

### Out of scope

- Upgrading Homebox past v0.20.2. That's a later, separate pin bump.
- Moving the port off 3100. Loki takes 3110 instead (PEP-HL-SLT-015).
- Retiring Portainer itself.

### Implementation Approach

1. Read the Portainer stack's compose file from Portainer's data volume on the
   host, and copy its env values and options into pillar.
2. Back up the volume before any change:
   `docker run --rm -v homebox_homebox-data:/data:ro -v /root:/backup alpine tar czf /backup/homebox-data-<date>.tgz -C /data .`
3. Salt state with the same project, service and container names, and the volume
   marked external. `test=True` should show only the new files. The first real
   apply runs `up -d`, and compose either adopts the container (same definition) or
   recreates it on the same volume (definition differs, e.g. image ref by tag).
4. Detach from Portainer: delete the stack in Portainer **with "remove volumes"
   unticked**, or leave it as a limited/external stack if Portainer offers that.
   Check the container and volume are still there afterwards.

### Success Criteria

- `docker inspect homebox` shows `com.docker.compose.project.working_dir=/docker/homebox`
  and image tag `v0.20.2`.
- Homebox at `http://docker:3100` shows the same items as before the takeover.
- A second `state.apply application.homebox test=True` shows no changes.
- Portainer no longer lists Homebox as one of its stacks.
- The Homepage Homebox widget shows data instead of 401.

## Implementation Plan

### Phase 0: Read and back up

- Locate Portainer's data volume and print the stack file:
  `cat "$(docker inspect portainer --format '{{range .Mounts}}{{if eq .Destination "/data"}}{{.Source}}{{end}}{{end}}')/compose/2/v1/docker-compose.yml"`.
  Check it for secrets before pasting it anywhere.
- **Portainer was wiped at some point (Timo, 2026-10-16)**, so the stack file is
  probably gone. That doesn't matter: the container and its volume are untouched by
  that. Rebuild the compose file from the running container instead:
  `docker inspect homebox --format '{{range .Config.Env}}{{println .}}{{end}}' | grep ^HBOX_`
  gives the env values (not secrets), and the image, port and volume are in the
  Motivation table.
- Volume backup (Implementation Approach step 2). Record the tarball's size. Stakes
  are low (about four boxes in it), and the fallback is a fresh Homebox, but the
  backup costs a minute.

### Phase 1: Salt takeover

- State and pillar. Add to the pillar top for `docker`, but leave it out of
  `salt/top.sls` until the first manual apply is clean (same as PEP-HL-SLT-028).
- `test=True`, apply, check the success criteria, then add it to `salt/top.sls`.

### Phase 2: Portainer detach

- Remove the stack from Portainer (volumes kept). Check the container, the volume
  and the data.

### Phase 3: Homepage widget

- Homebox user for the widget. Password into Vault. Homepage template reads it.

## Testing Strategy

- `test=True` before each apply. Expect only the new files and the start command.
- Before/after: item count in the Homebox UI, and `docker volume inspect homebox_homebox-data`
  shows the same volume (`CreatedAt` unchanged).
- Backout:
  - Phase 1: `docker compose -f /docker/homebox/docker-compose.yml down` (the volume
    is external, so it stays), then redeploy the stack from Portainer, which still
    has it until Phase 2. `git revert` the state.
  - After Phase 2: restore the volume from the tarball if needed, then
    `docker compose up -d` from the reverted file or a hand-written one.

## Documentation Requirements

- Vault note for the docker host's services: Homebox is Salt-managed, data in
  `homebox_homebox-data`, backup command.
- Homepage pillar: the widget's Vault key name.

## Risks and Mitigation

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Portainer stack delete removes the volume | Inventory data lost | Low | "Remove volumes" unticked; volume is external to the Salt compose; tarball backup in Phase 0 |
| Compose creates a second container or a new empty volume | Homebox starts empty | Medium | Same project/container names; volume `external: true` with the exact name; check before Phase 2 |
| Env values differ from the Portainer stack | Behaviour change (upload size, log format, storage path) | Low | Copied verbatim from the stack file in Phase 0 |
| Pinning `v0.20.2` by tag pulls a different image than the running digest | Unexpected change on first apply | Low | Compare the pulled image ID with `sha256:98f90e77b4e4…` before `up -d`; pin by digest if they differ |
| `docker system prune -af` at 02:00 while Homebox is stopped mid-takeover | Container removed (volume kept) | Low | Do the takeover in one sitting; volumes aren't pruned without `--volumes` |

## References

- PEP-HL-SLT-020 (restart handlers, pinned images)
- PEP-HL-SLT-015 (Loki on host port 3110 because Homebox holds 3100)
- PEP-HL-SLT-028 (the "pillar top first, salt top after a clean manual apply" pattern)

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 0.1 | 2026-10-10 | Timo Vlot | Initial draft |
| 0.2 | 2026-10-16 | Timo Vlot | Full draft from `docker inspect`: Portainer stack 2, volume `homebox_homebox-data`, v0.20.2 |
