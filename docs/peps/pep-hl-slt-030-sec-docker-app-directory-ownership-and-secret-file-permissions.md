# PEP-HL-SLT-030: Docker app directory ownership and secret file permissions

**ID:** PEP-HL-SLT-030  
**Title:** Docker app directory ownership and secret file permissions  
**Author:** Timo Vlot  
**Status:** Draft  
**Type:** Security  
**Priority:** Medium  
**Created:** 2026-10-17  
**Updated:** 2026-10-17  
**Supersedes:** N/A  
**Superseded-By:** N/A  

## Abstract

application.docker recursively resets everything under /docker to root:docker 0644 on every highstate, leaving secret-bearing .env files world-readable and fighting app states over ownership; drop the recursion and give each app its own permissions.

## Motivation

`salt/application/docker.sls` manages `/docker` with:

```yaml
/docker:
  file.directory:
    - user: root
    - group: docker
    - dir_mode: "0755"
    - file_mode: "0644"
    - recurse: [user, group, mode]
```

So on every highstate, every file under `/docker` becomes `root:docker 0644`, and
every directory becomes `root:docker 0755`. That includes files that app states
deliberately set otherwise, and files that containers write themselves.

Found 2026-10-17, while applying `application.loki` (PEP-HL-SLT-015). The `/docker`
state reported these changes:

- `/docker/linkwarden/.env` → mode **0644**. The file holds the Linkwarden database
  password, the database URL and `NEXTAUTH_SECRET`. `application.linkwarden` sets
  it to 0640, so the two states flap on every highstate, and the secrets are
  world-readable between runs.
- `/docker/heimdall2/data` → user **root**. `application.heimdall2` sets user 999
  (the container's user). Same flapping, and the container may lose write access.

The same survey also found:

- `/docker/heimdall2/.env` is **0644 by its own state** (`application.heimdall2`):
  `DATABASE_PASSWORD`, `JWT_SECRET`, `API_KEY_SECRET`. World-readable all the
  time, independent of the recursion.

On `docker`, "world-readable" means every local account and every process on the
host, not only `docker` group members (who are root-equivalent anyway). It's a
homelab host with few accounts, hence Medium, not High. But PEP-HL-SLT-018 is
adding named users to every VM, so the exposure grows.

The recursion also explains two workarounds already in the repo:
`application.prometheus` keeps its scrape token in `/etc/prometheus-secrets/` and
its TSDB in a named volume, because anything under `/docker` gets reset.

## Specification

### Requirements

- `/docker` itself stays managed (`root:docker 0755`), **without** `recurse`. Each
  app state owns the permissions of its own subtree, as most already do.
- Files with secrets are `root:docker 0640` at most, or `0600` where nothing but
  root (Salt, `docker compose` run by Salt) reads them. That covers:
  - `/docker/linkwarden/.env` (already 0640 in its state)
  - `/docker/heimdall2/.env` (0644 → 0640)
  - any other secret-bearing file the audit in Phase 2 finds
- Directories a container writes to keep the owner the app state gives them
  (e.g. `/docker/heimdall2/data` user 999).
- After the change, two highstates in a row on `docker` report no changes for
  `/docker` or any app state.

### Out of scope

- Moving secrets out of `.env` files into Docker secrets or Vault Agent templates.
  That's a bigger change. This PEP only fixes permissions.
- Prometheus's `/etc/prometheus-secrets` (already correct).
- Rotating the exposed secrets. It's listed as a decision in Phase 3, not a
  requirement.

### Implementation Approach

1. **One commit for the core fix:** remove `recurse` (and `file_mode`, which only
   applies with `recurse`) from `/docker`, and set `/docker/heimdall2/.env` to
   0640. Apply `application.docker`, then every app state on `docker` (a
   highstate), so each app restores its own permissions.
2. **Audit the rest:** list every file under `/docker` that's readable by others
   and looks like it holds a secret:
   `find /docker -type f -perm -o+r \( -name '.env*' -o -name '*secret*' -o -name '*token*' -o -name '*.key' \)`
   and read the Homepage config (`services.yaml`) for widget API keys. Homepage
   runs as PUID 1000 and has to read its config, so its fix may be group ownership
   (`root:1000 0640`) rather than plain 0640.
3. **Containers that write into bind mounts** (fing `data`, homepage `images`): leave
   their ownership to the container. Without `recurse`, Salt no longer touches it.

### Success Criteria

- `salt 'docker' state.apply test=True` twice in a row shows no `/docker` changes and
  no app-state permission changes.
- `salt 'docker' cmd.run "find /docker -type f -perm -o+r -name '.env*'"` returns
  nothing.
- `stat -c '%U %a' /docker/heimdall2/data` shows `999 755` after a highstate.
- Linkwarden, Heimdall2 and Homepage still start and work after the apply.

## Implementation Plan

### Phase 1: Stop the recursion (one commit)

- Edit `application.docker` and `application.heimdall2` (`.env` → 0640).
- `test=True` on `docker`: expect the `/docker` state to drop its recursion, and
  only the intended permission changes on app files.
- **Before pushing:** `chmod 0640 /docker/heimdall2/.env` on the host. Otherwise
  the mode change fires `heimdall2_restart`, which `watch`es the `.env` and runs
  `docker compose pull && up -d`: an unplanned Heimdall2 upgrade (the PEP-HL-SLT-020
  bug). With the file already at 0640, the state reports no change and the handler
  doesn't fire. Linkwarden's handler is gated on a check file Salt never writes, so
  it doesn't fire either. That's also why the 0644/0640 flapping never restarted
  Linkwarden.
- Apply the highstate. Check the success criteria and the three apps.

### Phase 2: Audit

- Run the `find` above and read Homepage's rendered config. Fix each secret-bearing
  file in its own app state.

### Phase 3: Exposure follow-up (decision)

- Decide whether to rotate the secrets that were world-readable: Linkwarden DB
  password and `NEXTAUTH_SECRET`, Heimdall2 DB password, `JWT_SECRET`,
  `API_KEY_SECRET`. Check `/etc/passwd` on `docker` for which accounts could have
  read them. If it's only root and `proxmox` (a docker group member,
  root-equivalent anyway), rotation is optional.

## Testing Strategy

- `test=True` before the apply. The diff should list only mode/owner changes, no
  content changes.
- After the apply: `ls -la /docker/*/.env`, `stat` on `heimdall2/data`, the
  success-criteria `find`, and a check that each app answers (Linkwarden, Heimdall2,
  Homepage in a browser).
- Second highstate: no changes.
- Backout: `git revert` the Phase 1 commit and apply. The recursion comes back and
  resets permissions as before. No data is touched either way, because only
  ownership and modes change.

## Documentation Requirements

- A comment on `/docker` in `application.docker`: no `recurse`, and each app owns
  its subtree.
- Comments in `application.prometheus` and `application.loki` mention the recursion
  as the reason for some choices. Update them so they don't mislead, but keep the
  named volumes (they're the better design anyway).

## Risks and Mitigation

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| An app relied on the recursion to fix its own permissions | App can't read or write its files | Low | Phase 1 highstate applies every app state, which sets its own perms; check each app after |
| Homepage can't read a 0640 config | Homepage shows errors | Medium | Phase 2 handles Homepage separately (group 1000) |
| Secrets were read while world-readable | Credential misuse | Low (few local accounts) | Phase 3 decision on rotation |
| New app states written without explicit perms | Defaults from umask | Low | Repo pattern: every `file.directory`/`file.managed` under `/docker` sets user, group and mode |

## References

- PEP-HL-SLT-015, PEP-HL-SLT-028 (where the recursion was found, and the
  workarounds it caused)
- PEP-HL-SLT-018 (named users on all VMs, which widens the exposure)
- PEP-HL-SLT-020 (Docker restart handlers, same apps)
- PEP-HL-SLT-016 (homelab hardening rollout)

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 0.1 | 2026-10-17 | Timo Vlot | Initial draft |
