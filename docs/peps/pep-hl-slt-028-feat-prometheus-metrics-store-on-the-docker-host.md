# PEP-HL-SLT-028: Prometheus metrics store on the docker host

**ID:** PEP-HL-SLT-028  
**Title:** Prometheus metrics store on the docker host  
**Author:** Timo Vlot  
**Status:** Draft  
**Type:** Feature  
**Priority:** Medium  
**Created:** 2026-10-16  
**Updated:** 2026-10-16  
**Supersedes:** N/A  
**Superseded-By:** N/A  

## Abstract

Prometheus on the docker host as the homelab metrics store, receiving OTLP metrics from the central Alloy and scraping Home Assistant.

## Motivation

The vault project `homelab-telemetry-claude-bambu` wants two sets of numbers in
Grafana: Claude Code usage and cost, and Bambu A1 print usage. Both are metrics, not
logs:

- Claude Code exports `claude_code.cost.usage`, `claude_code.token.usage` and the
  related counters over OTLP. The central Alloy (PEP-HL-SLT-015) receives them and
  needs somewhere to write them.
- Bambu data comes from Home Assistant's existing Bambu integration (`ha-bambulab`),
  exposed through HA's `prometheus:` integration. The printer stays out of LAN-only
  mode, so the linked Bambu exporter is not used.

Zabbix is the wrong store for either. Both are push/scrape time series with labels
(model, token type, entity), and the dashboards that come with them are PromQL. The
docker pillar already reserves `prometheus` (9090) and `alertmanager` (9093) on the
docker host, but no state manages them.

Decided 2026-10-16: the observability stack runs only on the dedicated docker host.
No Docker on general servers.

## Specification

### Requirements

- Prometheus in Docker on the docker host, managed like the other compose apps:
  `salt/application/prometheus.sls` writing `/docker/prometheus/` (compose file,
  `prometheus.yml`), including `application.docker`.
- Image tag pinned in pillar, never `:latest`, with an in-place `up -d` on change
  (PEP-HL-SLT-020 pattern).
- Remote-write receiver enabled (`--web.enable-remote-write-receiver`) so Alloy can
  push to it.
- Retention from pillar (`storage.tsdb.retention.time`, default `400d`). Cost history
  is the point, and the series count is small.
- TSDB on the docker host's local disk, not NFS. Prometheus doesn't support NFS for
  its TSDB, so the hardening plan's `pool/prometheus-storage` NFS dataset is dropped
  for this. Backups are the host's vzdump.
- Scrape jobs rendered from pillar: Prometheus itself, Alloy's own metrics, and Home
  Assistant (`/api/prometheus`, bearer token).
- HA long-lived token in Vault, read through the existing Vault pillar. Never in git.
- Grafana datasource for Prometheus, provisioned by `application.grafana`.
- **Claude usage inputs** (Phase 4). Neither is available over OTel:
  - **Pushgateway** container on the docker host, image pinned, scraped with
    `honor_labels: true`. Personal Macs' Claude Code status line scripts push the
    Pro plan `rate_limits` (5-hour and 7-day `used_percentage`, `resets_at`) to it.
    Reachable over Tailscale only.
  - **Cost exporter** container that polls the Admin API
    `GET /v1/organizations/cost_report` at most hourly (the data is daily buckets)
    and exposes USD spend per model as Prometheus metrics. It also exposes the
    credit left as `topup_usd` minus spend since `topup_date`, both from pillar,
    because no API exposes the prepaid balance. Admin API key from Vault.

### Out of scope

- Alertmanager: the pillar entry stays reserved, nothing is deployed.
- Node exporters on other hosts. Zabbix keeps host metrics.
- The HA side (`prometheus:` block in HA's `configuration.yaml`). HA isn't
  Salt-managed. That's a hand step in the vault project.
- Long-term storage (Mimir): `observability-redesign` Phase 2+.
- Writing the cost exporter itself. It's a small program in its own repo. This PEP
  deploys it.
- Anything from the work MacBook. Its Claude Code telemetry carries the work org ID
  and email, so it never points at this stack.

### Implementation Approach

```
central Alloy (PEP-015) ──remote_write──► Prometheus :9090 ◄──scrape── Home Assistant
                                              ▲
                                     Grafana datasource
```

- Pillar `pillar/application/prometheus.sls`: image tag, retention, scrape targets,
  and the Vault key name for the HA token.
- `prometheus.yml` built from pillar with Jinja. `promtool check config` runs as a
  `check_cmd` before the file is replaced.
- Prometheus 3.x also has a native OTLP endpoint (`--web.enable-otlp-receiver`).
  Remote write from Alloy stays the route, because Alloy also does the relabelling
  and series filtering.

### Success Criteria

- `curl -s http://<docker-host>:9090/-/ready` returns `Prometheus Server is Ready.`
- `up{job="homeassistant"} == 1`, and at least one Bambu entity series is present
  (`count({__name__=~"homeassistant_.*", entity=~".*bambu.*|.*a1.*"})` > 0).
- `claude_code_cost_usage_USD_total` (or whatever name Alloy produces) appears within
  one export interval of a Claude Code session on a personal Mac.
- Grafana's Prometheus datasource "Save & test" passes.
- Two highstates in a row show no changes.

## Implementation Plan

### Phase 0: Survey

- Check the docker host for a hand-run `prometheus` or `alertmanager` container. If
  one exists, note its data path and decide whether to adopt or discard its data.

### Phase 1: Prometheus

- State, pillar and compose file. Self-scrape only.
- Apply with `test=True`, then for real. Check readiness.

### Phase 2: Scrape Home Assistant

- HA token into Vault. HA `prometheus:` block, filtered to Bambu entities (hand step).
- Add the scrape job. Check `up` and the entity series.

### Phase 3: Grafana

- Datasource provisioning in `application.grafana`.

### Phase 4: Claude usage inputs

- Pushgateway container and scrape job. Check one push from a personal Mac.
- Admin API: confirm the Console account is an organization (the Admin API is
  unavailable for individual accounts). Admin key into Vault.
- Cost exporter container and scrape job. Compare one day's figure with the
  Console's Cost page.

Alloy's remote write lands with PEP-HL-SLT-015 Phase 1.

## Testing Strategy

- `test=True` on the docker host before every apply.
- `promtool check config` as the `check_cmd` on `prometheus.yml`.
- Readiness and `up` queries from the Success Criteria, run by hand after each phase.
- Backout: `docker compose -f /docker/prometheus/docker-compose.yml down`, remove the
  state from `top.sls`, `git revert <sha>`. Nothing else depends on Prometheus until
  PEP-015 Phase 1 points Alloy at it. Revoke the HA token in HA.

## Documentation Requirements

- Vault: `homelab-telemetry-claude-bambu` (project), `observability-redesign`
  (architecture), `homelab-hardening-and-monitoring-implementation-plan` Phase 4 (NFS
  storage dropped for Prometheus).

## Risks and Mitigation

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| HA exports every entity | Cardinality and disk growth | Medium | `filter:` in HA's `prometheus:` block, plus `metric_relabel_configs` keeping only Bambu series |
| HA token leaks via the rendered `prometheus.yml` | HA admin access | Low | Token in a separate file (`bearer_token_file`, mode 0600), not inline; file from Vault pillar |
| Docker host disk fills | Other containers fail | Low | Retention from pillar; Zabbix already watches the docker host's disk |
| A hand-run container already holds 9090 | Compose fails to start | Medium | Phase 0 survey |
| Admin API key leaks | Full org admin on the Anthropic account | Low | Key only in Vault, read-only use, mounted as a file; rotate on any doubt |
| Stale Pushgateway values when no session runs | Dashboard shows old plan usage as current | High | Push a timestamp metric too; panel greys out past `resets_at` |

## References

- PEP-HL-SLT-015 (Loki and Alloy, the central Alloy that writes here)
- PEP-HL-SLT-016 (homelab hardening rollout, which overlaps the vault plan's Phase 4)
- PEP-HL-SLT-020 (compose restart handlers, pinned images)
- Vault: `homelab-telemetry-claude-bambu`, `observability-redesign`
- Prometheus storage docs: NFS not supported for the TSDB

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 0.1 | 2026-10-16 | Timo Vlot | Initial draft |
| 0.2 | 2026-10-16 | Timo Vlot | Phase 4: Pushgateway for Pro plan usage, cost exporter for API spend |
