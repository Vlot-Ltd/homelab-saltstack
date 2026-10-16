# pillar/application/loki.sls
# PEP-HL-SLT-015: Loki and the central Alloy on the docker host. Pure data.

loki:
  # Pinned, never :latest (PEP-HL-SLT-020). Bump deliberately.
  image: grafana/loki:3.5.0
  # Host port 3110: homebox holds 3100 (decided 2026-10-16). Container stays 3100.
  port: 3110
  retention: 720h        # 30 days

alloy:
  image: grafana/alloy:v1.10.0
  otlp_grpc_port: 4317
  otlp_http_port: 4318
  ui_port: 12345
  # Resource attributes copied onto every metric as labels, so Prometheus can
  # split by machine and by billing route (Claude Code's OTEL_RESOURCE_ATTRIBUTES).
  promote_resource_attributes:
    - host
    - billing
