# PEP-HL-SLT-015: Loki and Alloy log aggregation states

**ID:** PEP-HL-SLT-015  
**Title:** Loki and Alloy log aggregation states  
**Author:** Timo Vlot  
**Status:** Draft  
**Type:** Feature  
**Priority:** Medium  
**Created:** 2026-10-10  
**Updated:** 2026-10-17  
**Supersedes:** N/A  
**Superseded-By:** N/A  

## Abstract

Loki server and Alloy agent states for log aggregation, from the draft in the vault (loki-alloy-log-aggregation).

## Motivation

JARVIS depends on it (raised from Low on 2026-10-10): pulling LLM usage data needs Claude Code's OpenTelemetry output collected, and that needs Alloy configured. See `jarvis-project-overview` in the vault ("To review once OpenTelemetry is running").

The vault project `homelab-telemetry-claude-bambu` (2026-10-16) needs this PEP's
Phase 1: a central Alloy that receives Claude Code's OTLP output. Alloy sends the
metrics to Prometheus (PEP-HL-SLT-028) and the events to Loki. Alloy replaces a
separate OTel Collector.

Log aggregation from the other hosts is the original goal and follows in later
phases.

Decided 2026-10-16: Loki and the central Alloy run in Docker on the dedicated docker
host only. Every other host runs Alloy as a native apt package, with no Docker. No
Docker on general servers. PatchMon is the exception, not the pattern.

## Specification

### Requirements

- **Loki** in Docker on the docker host (`salt/application/loki.sls`, `/docker/loki/`).
  Single binary, filesystem storage on local disk, retention from pillar (default
  30 days). Image tag pinned.
- **Central Alloy** in Docker on the docker host, in the same state:
  - `otelcol.receiver.otlp` on 4317 (gRPC) and 4318 (HTTP)
  - metrics → `otelcol.exporter.prometheus` → `prometheus.remote_write` to PEP-028
  - logs and events → `otelcol.exporter.loki` → `loki.write`
  - reachable from personal Macs over Tailscale through a Tailscale Service
    (PEP-HL-SLT-019 pattern), so laptops off the LAN can send telemetry
- **Alloy agents** on Linux hosts: Grafana's apt repo, package pinned in pillar,
  `config.alloy` from a template, `alloy` user in `systemd-journal` and `adm`. Ships
  the journal and pillar-listed files to Loki.
- `salt/os/linux/init.sls` currently **removes** `alloy` and `grafana-agent` and
  sets `user.absent` for both on every Linux host. The `alloy` entries come out in the
  same commit that adds the agent state, or the two fight on every highstate.
  `grafana-agent` stays removed.
- No secrets in pillar files. Loki has no auth on the LAN. The Tailscale ACL limits
  who can reach the OTLP ports.

### Out of scope

- Prometheus itself (PEP-HL-SLT-028).
- macOS minions: the Macs send OTLP straight from Claude Code. No Alloy agent there.
- Work hosts. The vault runbook covers both sides, but this repo is homelab only.
- Tempo/traces (`observability-redesign` Phase 2+).

### Implementation Approach

```
Personal Macs (Claude Code) ──OTLP over Tailscale──┐
                                                   ▼
docker host:  Alloy (central) ──metrics──► Prometheus (PEP-028)
                    └────────logs/events──► Loki :3100 ◄──push── Alloy agents (native, all Linux VMs)
```

- Starting point: vault `loki-alloy-log-aggregation` (states and pillar shape) and
  `observability-redesign` (Alloy config). The redesign's compose file assumed Loki
  on the Grafana/Zabbix host with journal mounts. That was reversed 2026-10-16, so
  its journal and root-in-container parts are not carried over.
- Pillar `pillar/application/loki.sls` (image tags, retention, ports) and
  `pillar/monitoring/alloy/defaults.sls` (Loki endpoint, agent package version).
  Per-host file lists in host pillar.
- Host port clash: `pillar/application/docker.sls` gives both `homebox` and `loki`
  port 3100, and homebox really holds it (checked 2026-10-16). **Decided
  2026-10-16:** Loki publishes host port **3110** on the docker host; the container
  still listens on 3100. Pillar `loki.port` changes to 3110.

### Success Criteria

- `curl -s http://<docker-host>:<loki-port>/ready` returns `ready`.
- A Claude Code session on a personal Mac shows up in Loki
  (`{service_name="claude-code"}`) and its metrics in Prometheus within one export
  interval.
- After Phase 2: `{host="<test-vm>", job="systemd-journal"}` returns lines in Grafana
  Explore.
- Two highstates in a row show no changes on the docker host and every agent host.
  In particular, `alloy` is no longer removed by `os.linux`.

## Implementation Plan

### Phase 1: Loki and central Alloy on the docker host

- Loki on host port 3110. Loki and central Alloy state, pillar and compose file.
- Tailscale Service for the OTLP endpoint.
- Point one personal Mac's Claude Code at it (chezmoi, outside this repo) and check
  both stores.
- **Stack done 2026-10-17** (commit `263d24f`): `application.loki` applied on
  `docker`. Loki `/ready` returns `ready`, Alloy `/-/ready` returns `Alloy is ready.`,
  and a second `test=True` run shows no changes. An OTLP/HTTP test gauge posted from
  the Mac to `docker:4318` arrived in Prometheus as
  `otel_pipeline_test{host="timo-mac", job="otel-test"}`, so the label promotion
  works. Added to `salt/top.sls`. Still to do: the Tailscale Service for the OTLP
  endpoint, and Claude Code on a Mac.

### Phase 2: One agent

- Remove `alloy` from `os.linux`'s removal lists. Add `monitoring.alloy` targeted at
  one VM only.
- Check the journal arrives. Check two clean highstates.

### Phase 3: Rest of the Linux fleet, staggered

- Small groups first, then add it to the common Linux top entry.
- Per-host file collection (Apache, ClamAV and so on) from host pillar.

## Testing Strategy

- `test=True` before every apply. Expect only the new states, and on agent hosts
  the removed `pkg.removed`/`user.absent` changes.
- `alloy fmt` / `alloy validate` (where the installed version has it) as a
  `check_cmd` on `config.alloy`.
- Loki `/ready`, Grafana Explore queries and Alloy's UI (`:12345`) after each phase.
- Backout:
  - Phase 1: `docker compose -f /docker/loki/docker-compose.yml down` and unset the
    Claude Code env vars on the Mac.
  - Phase 2/3: `git revert <sha>`, which puts the `pkg.removed` back, and the next
    highstate removes the agent.

## Documentation Requirements

- Vault: `loki-alloy-log-aggregation` (update the runbook to the docker-host model
  and real states once built), `observability-redesign`,
  `homelab-telemetry-claude-bambu`, `homelab-hardening-and-monitoring-implementation-plan`
  Phase 3.

## Risks and Mitigation

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| `os.linux` and the agent state fight over the `alloy` package | Package flaps every highstate | High if missed | Same commit removes it from the removal lists; checked in Phase 2 |
| Loki/homebox both on host port 3100 | One container fails to start | High | Decided: Loki on 3110 |
| OTLP endpoint open beyond personal devices | Anyone on the tailnet can write telemetry | Medium | Tailscale ACL limits 4317/4318 to my devices |
| Claude Code events carry prompt text | Prompts stored in Loki | Low | `OTEL_LOG_USER_PROMPTS` left unset on every Mac |
| Journal volume from the whole fleet | Docker host disk fills | Medium | Retention from pillar; staggered Phase 3; Zabbix disk trigger on the docker host |

## References

- PEP-HL-SLT-028 (Prometheus, where the metrics go)
- PEP-HL-SLT-019 (Tailscale Services), PEP-HL-SLT-020 (pinned images, in-place recreate)
- PEP-HL-SLT-016 (homelab hardening rollout, which overlaps the vault plan's Phase 3)
- Vault: `loki-alloy-log-aggregation`, `observability-redesign`,
  `homelab-telemetry-claude-bambu`, `thousandeyes-otel-ingest` §5 (Alloy, not Promtail)

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 0.1 | 2026-10-10 | Timo Vlot | Initial draft |
| 0.2 | 2026-10-16 | Timo Vlot | Full draft: docker-host model, central Alloy with OTLP for Claude Code, `os.linux` removal conflict, port 3100 clash |
