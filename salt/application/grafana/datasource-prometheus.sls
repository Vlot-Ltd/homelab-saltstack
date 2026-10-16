# PEP-HL-SLT-028 Phase 3: Prometheus datasource for Grafana.
#
# Standalone on purpose: it does not include application.grafana, whose init.sls
# overwrites grafana.ini wholesale and whose datasource template can't render a
# datasource without a password. Grafana reads every file in the provisioning
# directory, so this file sits next to whatever is there already.
{%- set url = salt['pillar.get']('grafana_prometheus_url', 'http://docker:9090') %}

grafana-datasource-prometheus:
  file.managed:
    - name: /etc/grafana/provisioning/datasources/prometheus.yaml
    - user: root
    - group: grafana
    - mode: "0640"
    - contents: |
        # Managed by Salt (application.grafana.datasource-prometheus, PEP-HL-SLT-028).
        apiVersion: 1
        datasources:
          - name: Prometheus
            uid: prometheus
            type: prometheus
            access: proxy
            url: {{ url }}
            isDefault: false
            editable: false
            jsonData:
              httpMethod: POST
              timeInterval: 60s

# Provisioning is read at startup, so a changed file needs a restart.
grafana-restart-for-prometheus-datasource:
  service.running:
    - name: grafana-server
    - watch:
      - file: grafana-datasource-prometheus
