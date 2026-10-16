# PEP-HL-SLT-028: Prometheus metrics store on the docker host

**ID:** PEP-HL-SLT-028  
**Title:** Prometheus metrics store on the docker host  
**Author:** Timo Vlot  
**Status:** Draft  
**Type:** Feature  
**Priority:** Medium  
**Created:** 2026-10-16  
**Updated:** 2026-10-17  
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
  - **API spend, without the Admin API** (decided 2026-10-16). The Console account
    is individual, so the Admin API isn't available, and an organization isn't
    needed. All API (non-Pro) use runs on `friday`, through two routes:
    - `claude -p` jobs with `ANTHROPIC_API_KEY`: Claude Code's OTel cost metric,
      tagged `billing=api` by the job's own env file, so Pro sessions
      (`billing=pro`) never mix in.
    - LiteLLM on `friday`: Prometheus scrape of its `/metrics`
      (`litellm_spend_metric` by model and key alias). That needs
      `callbacks: ["prometheus"]` in LiteLLM's config, and since LiteLLM v1.85.0
      `/metrics` needs an API key. LiteLLM's virtual key goes in Vault.
  - **Credit left** is a Grafana calculation: `topup_usd` minus the `billing=api`
    and LiteLLM spend since `topup_date`. Both values are in pillar and exported by
    Pushgateway after each top-up, because no API exposes the prepaid balance.

### Out of scope

- Alertmanager: the pillar entry stays reserved, nothing is deployed.
- Node exporters on other hosts. Zabbix keeps host metrics.
- The HA side (`prometheus:` block in HA's `configuration.yaml`). HA isn't
  Salt-managed. That's a hand step in the vault project.
- Long-term storage (Mimir): `observability-redesign` Phase 2+.
- LiteLLM's own config on `friday` (PEP-HL-SLT-014). This PEP only adds the scrape
  job.
- Whether the work MacBook reports is decided in the vault project, not here. It
  uses the personal subscription, so it would only be a client config change.

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
- **Done 2026-10-16:** `docker ps -a` shows no Prometheus, Loki, Alertmanager or
  Alloy containers. The `prometheus`, `loki` and `alertmanager` entries in
  `pillar/application/docker.sls` are reservations only. Homebox holds host port
  3100 (see PEP-HL-SLT-015). `/docker` is on the root LV: 48 GB, 21 GB free.

### Phase 1: Prometheus

- State, pillar and compose file. Self-scrape only.
- Apply with `test=True`, then for real. Check readiness.
- **Done 2026-10-17:** `application.prometheus` applied on `docker` (commit
  `5328227`). `/-/ready` returns `Prometheus Server is Ready.`, and a second
  `test=True` run shows no changes. Image `prom/prometheus:v3.5.0`, TSDB in the
  named volume `prometheus-data`. Added to `salt/top.sls` for `docker`.

### Phase 2: Scrape Home Assistant

- HA token into Vault. HA `prometheus:` block, filtered to Bambu entities (hand step).
- Add the scrape job. Check `up` and the entity series.

### Phase 3: Grafana

- Datasource as a **standalone state**, `application.grafana.datasource-prometheus`,
  writing `/etc/grafana/provisioning/datasources/prometheus.yaml` and restarting
  `grafana-server` when the file changes. URL from pillar `grafana_prometheus_url`.
- Not through `application.grafana` (2026-10-17). That state isn't in
  `salt/top.sls` and has never been applied by highstate, and applying it would:
  - overwrite `/etc/grafana/grafana.ini` with only a `[security]` section
  - fail to render a datasource without `secureJsonData.password_key`
  - drop `isDefault`, `trends` and `directDbConnection` from the Zabbix datasource

  Fixing that state is separate work, not this PEP.

### Phase 4: Claude usage inputs

- Pushgateway container and scrape job. Check one push from a personal Mac.
- LiteLLM scrape job, using a LiteLLM key from Vault.
- `billing=api` resource attribute in the `friday` job env files.
- Compare one week's `billing=api` + LiteLLM total with the Console's usage page.
  They should agree within rounding.

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
| An API job runs without the `billing=api` tag | API spend shows up as Pro, or is missing | Medium | The tag lives in the same env file that sets `ANTHROPIC_API_KEY`, so one can't exist without the other; weekly comparison with the Console |
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
| 0.3 | 2026-10-16 | Timo Vlot | Cost exporter dropped (Console account is individual, so no Admin API). API spend from Claude Code OTel `billing=api` plus a LiteLLM scrape |
