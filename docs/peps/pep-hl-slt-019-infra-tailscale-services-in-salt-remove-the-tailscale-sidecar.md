# PEP-HL-SLT-019: Tailscale Services in Salt; remove the tailscale-sidecar

**ID:** PEP-HL-SLT-019  
**Title:** Tailscale Services in Salt; remove the tailscale-sidecar  
**Author:** Timo Vlot  
**Status:** Draft  
**Type:** Infrastructure  
**Priority:** Medium  
**Created:** 2026-10-10  
**Updated:** 2026-10-10  
**Supersedes:** N/A  
**Superseded-By:** N/A  

## Abstract

Tailscale Services are already how homelab apps get HTTPS names, but they were set up by hand and aren't in this repo. This PEP manages each host's Services from Salt, and removes the `tailscale-sidecar` container on `docker`, which serves nothing.

## Motivation

State on 2026-10-10:

- Services, each served by the host's own `tailscaled` to a port published on that host:
  - `docker`: `heimdall2` → 127.0.0.1:8080, `homepage` → 127.0.0.1:3000, `linkwarden` → 127.0.0.1:3200
  - `plex`: `plexmedia`; `manyfold`: `manyfoldstl`; `patch`: `mirror` (removed by PEP-HL-SLT-013); `friday`: `llm` (LiteLLM, added 2026-10-10)
- `tailscale-sidecar` (`application/tailscale-docker.sls`, tailnet node `homelab`, `tag:container`) has no serve config; nothing is proxied through it. Its only remaining job is creating the `tailnet` Docker network.
- `homepage`, `heimdall2` and `linkwarden` include `application.tailscale-docker` and attach to `tailnet` as an external network; homepage and heimdall2 states require `cmd: start-tailscale-docker`.
- Live drift: the `linkwarden` container runs on `linkwarden_default`, not `tailnet`, so the Salt compose file isn't what's running.
- The sidecar's `TS_AUTHKEY` is written into a 0644 compose file.
- Nothing records which host serves which Service: a rebuilt VM loses its Services.

## Specification

### Requirements

- Per-host Services from pillar, e.g. `tailscale:services: {homepage: {https: 443, target: http://127.0.0.1:3000}}`, applied with `tailscale serve --bg --service=svc:<name> --https=443 <target>`; idempotent (compare `tailscale serve status --json` before changing)
- Sidecar removed: container, compose file, state, the `tailnet` network dependency in the three app states, and the `homelab` node in the Tailscale admin console
- Apps keep their published host ports (Services proxy to them); the `tailnet` network is dropped from their compose files unless something needs container-to-container traffic on it
- `tailscale_container_authkey` in Vault `salt/general` retired if nothing else uses it
- Service definitions in the admin console stay manual until the Tailscale policy project ([[homelab-tailscale-acl-policy]] in the vault) puts the policy in git

### Implementation Approach

1. Pillar for Services on each host; a `tailscale.services` state
2. Apply to `friday` first (`llm` only), then `docker`
3. Remove the sidecar and the network dependency from homepage, heimdall2, linkwarden; reconcile linkwarden's drift
4. Remove `homelab` from the tailnet

### Success Criteria

- `tailscale serve status` on each host matches pillar; a highstate makes no changes
- All Service URLs answer over HTTPS after a `docker` highstate
- `tailscale-sidecar` gone from `docker ps`; `homelab` gone from the tailnet
- No auth key in any compose file

## Implementation Plan

### Phase 1: Services in Salt (friday, then docker)

### Phase 2: remove the sidecar

### Phase 3: plex, manyfold

## Testing Strategy

`test=True` per host; curl every Service URL before and after; Homepage tiles all load.

## Documentation Requirements

Vault `homelab-tailscale-https`: Services as the pattern, which host serves what.

## Risks and Mitigation

- Removing the network breaks container links: check for container-to-container traffic on `tailnet` first (none known; the apps use host ports).
- A wrong serve command replaces a working Service: record `tailscale serve status --json` per host before Phase 1.

**Backout:** restore each host's serve config from the saved JSON (`tailscale serve set-raw`), and `git revert` the commits to bring back the sidecar state.

## References

- PEP-HL-SLT-006 (the sidecar's start-check bug and the 0644 key)
- PEP-HL-SLT-013 (removes `mirror`)
- Vault: `30-projects/homelab-tailscale-https.md`, `30-projects/homelab-tailscale-acl-policy.md`

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 0.1 | 2026-10-10 | Timo Vlot | Initial draft |
