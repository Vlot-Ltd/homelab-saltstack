# Add Grafana Repository
grafana-repo:
  cmd.run:
    - name: >
        wget -q -O - https://packages.grafana.com/gpg.key | gpg --dearmor -o /usr/share/keyrings/grafana-archive-keyring.gpg &&
        echo "deb [signed-by=/usr/share/keyrings/grafana-archive-keyring.gpg] https://packages.grafana.com/oss/deb stable main"
        | tee /etc/apt/sources.list.d/grafana.list
    - creates: /etc/apt/sources.list.d/grafana.list

# Update Packages
grafana-apt-update:
  cmd.run:
    - name: apt update
    - onchanges:
        - cmd: grafana-repo

# Install Grafana
grafana-install:
  pkg.installed:
    - name: grafana
    - require:
        - cmd: grafana-apt-update

# Start and Enable Grafana Service
grafana-service:
  service.running:
    - name: grafana-server
    - enable: True
    - require:
        - pkg: grafana-install

# Set Grafana Admin Password
grafana-set-admin-password:
  file.managed:
    - name: /etc/grafana/grafana.ini
    - mode: "0644"
    - contents: |
        [security]
        admin_password = {{ salt['pillar.get']('grafana_admin_password', 'admin') }}
    - require:
        - service: grafana-service
    - watch_in:
        - service: grafana-service

# Ensure Grafana CLI is Available
grafana-cli-check:
  cmd.run:
    - name: grafana-cli plugins list-remote
    - require:
        - service: grafana-service

# Install Zabbix Plugin for Grafana
grafana-install-zabbix-plugin:
  cmd.run:
    - name: grafana-cli plugins install alexanderzobnin-zabbix-app
    - unless: grafana-cli plugins ls | grep -q "alexanderzobnin-zabbix-app"
    - require:
        - cmd: grafana-cli-check

# Restart Grafana After Plugin Installation
grafana-restart-after-plugin:
  service.running:
    - name: grafana-server
    - enable: True
    - watch:
        - cmd: grafana-install-zabbix-plugin

# Deploy Grafana Datasource Configuration
grafana-datasources:
  file.managed:
    - name: /etc/grafana/provisioning/datasources/datasources.yaml
    - mode: "0644"
    - contents: |
        apiVersion: 1
        datasources:
        {% for datasource in salt['pillar.get']('grafana_datasources', []) %}
          - name: {{ datasource.name }}
            type: {{ datasource.type }}
            access: {{ datasource.access }}
            url: {{ datasource.url }}
            database: {{ datasource.get('database', '') }}
            user: {{ datasource.get('user', '') }}
            secureJsonData:
              password: {{ datasource.secureJsonData.password }}
            jsonData:
              sslmode: {{ datasource.jsonData.get('sslmode', 'disable') }}
              username: {{ datasource.jsonData.get('username', '') }}
        {% endfor %}
    - require:
        - service: grafana-service
    - watch_in:
        - service: grafana-service