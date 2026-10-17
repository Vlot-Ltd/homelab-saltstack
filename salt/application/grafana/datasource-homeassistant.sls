# PEP-HL-SLT-028: Home Assistant as a Grafana datasource, through the Infinity
# plugin (JSON from HA's REST API). Used by the Bambu dashboard's "Now printing"
# row (job name and cover image from sensor.a1_current_job).
#
# Standalone, like datasource-prometheus.sls: doesn't include application.grafana
# (see PEP-HL-SLT-029 for why). Token: Vault salt/minions/zabbix, key
# homeassistant_grafana_token (a long-lived HA token, own one for Grafana).
{%- set ha_url = salt['pillar.get']('grafana_homeassistant_url', 'http://192.168.0.24:8123') %}

# grafana-cli is deprecated and, run outside the service, can't find Grafana's
# homepath or the Debian package's plugin dir. Spell both out (hit 2026-10-17).
grafana-plugin-infinity:
  cmd.run:
    - name: >-
        grafana cli --homepath /usr/share/grafana --config /etc/grafana/grafana.ini
        --pluginsDir /var/lib/grafana/plugins plugins install yesoreyeram-infinity-datasource
    - unless: test -d /var/lib/grafana/plugins/yesoreyeram-infinity-datasource

grafana-datasource-homeassistant:
  file.managed:
    - name: /etc/grafana/provisioning/datasources/homeassistant.yaml
    - user: root
    - group: grafana
    - mode: "0640"
    - show_changes: False
    - contents: |
        # Managed by Salt (application.grafana.datasource-homeassistant, PEP-HL-SLT-028).
        apiVersion: 1
        datasources:
          - name: Home Assistant
            uid: homeassistant
            type: yesoreyeram-infinity-datasource
            editable: false
            jsonData:
              auth_method: bearerToken
              allowedHosts:
                - {{ ha_url }}
            secureJsonData:
              bearerToken: {{ salt['pillar.get']('homeassistant_grafana_token', '') | trim | yaml_dquote }}
    - require:
      - cmd: grafana-plugin-infinity

# Plugins and provisioning are read at startup.
grafana-restart-for-homeassistant-datasource:
  service.running:
    - name: grafana-server
    - watch:
      - cmd: grafana-plugin-infinity
      - file: grafana-datasource-homeassistant
