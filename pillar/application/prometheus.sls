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

  # Docker's DNS returns only the IPv6 address for Tailscale Service names, and
  # the container has no IPv6. Pin the Service's IPv4 VIP (stable unless the
  # Service is deleted and recreated). From: dig llm.taile3eee.ts.net A @100.100.100.100
  extra_hosts:
    llm.taile3eee.ts.net: 100.65.24.13

  # Extra scrape jobs, rendered as-is into prometheus.yml.
  scrape_configs:
    # Phase 4: LiteLLM on friday (all tiers: local/Ollama, cheap, smart).
    # /metrics is unauthenticated (require_auth_for_metrics_endpoint: false in
    # LiteLLM's config): read-only counters, tailnet-only. Decided 2026-10-17.
    - job_name: litellm
      scheme: https
      # Trailing slash: LiteLLM 307-redirects /metrics to /metrics/, and behind the
      # Tailscale Service the redirect points at http://...:443, which fails (400).
      metrics_path: /metrics/
      scrape_interval: 60s
      static_configs:
        - targets: ["llm.taile3eee.ts.net:443"]
