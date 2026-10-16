# pillar/application/prometheus.sls
# PEP-HL-SLT-028: Prometheus metrics store on the docker host.
# Pure data. Secrets (HA token, LiteLLM key) come from Vault pillar in later phases.

prometheus:
  # Pinned, never :latest (PEP-HL-SLT-020). v3.5 is the Prometheus LTS line;
  # bump deliberately after checking the release notes.
  image: prom/prometheus:v3.5.0
  port: 9090
  retention: 400d
  scrape_interval: 60s

  # Phase 2: Home Assistant (Bambu A1 via ha-bambulab). Token from Vault
  # salt/minions/docker, key homeassistant_prometheus_token. IP, not the name:
  # containers don't read the host's /etc/hosts (192.168.0.24 = homeassistant).
  homeassistant:
    enabled: true
    target: "192.168.0.24:8123"
    scrape_interval: 60s

  # Extra scrape jobs, rendered as-is into prometheus.yml. Phase 2 adds Home
  # Assistant, Phase 4 adds LiteLLM and Pushgateway.
  scrape_configs: []
