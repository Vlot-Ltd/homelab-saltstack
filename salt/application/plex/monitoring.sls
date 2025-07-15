{% set plex_url = salt['pillar.get']('plex_url', 'http://192.168.1.3:32400') %}
{% set plex_token = salt['pillar.get']('plex_token', '') %}

install-uv:
  cmd.run:
    - name: curl -LsSf https://astral.sh/uv/install.sh | sh
    - unless: which uv
    - runas: root

plex-monitoring-project:
  file.directory:
    - name: /opt/plex-monitoring
    - user: root
    - group: root
    - mode: '0755'
    - makedirs: True

plex-monitoring-pyproject:
  file.managed:
    - name: /opt/plex-monitoring/pyproject.toml
    - source: salt://application/plex/files/pyproject.toml
    - mode: '0644'
    - user: root
    - group: root
    - require:
      - file: plex-monitoring-project

setup-plex-monitoring-env:
  cmd.run:
    - name: |
        cd /opt/plex-monitoring
        /root/.cargo/bin/uv sync
    - creates: /opt/plex-monitoring/.venv/bin/python
    - require:
      - cmd: install-uv
      - file: plex-monitoring-pyproject

plex-monitoring-directory:
  file.directory:
    - name: /etc/zabbix/bin
    - user: root
    - group: root
    - mode: '0755'
    - makedirs: True

plex-monitoring-script:
  file.managed:
    - name: /opt/plex-monitoring/plex_monitor.py
    - source: salt://application/plex/files/plex_monitor.py
    - mode: '0755'
    - user: root
    - group: root
    - require:
      - file: plex-monitoring-project
      - cmd: setup-plex-monitoring-env

plex-maintenance-monitoring-script:
  file.managed:
    - name: /opt/plex-monitoring/plex_maintenance_monitor.py
    - source: salt://application/plex/files/plex_maintenance_monitor.py
    - mode: '0755'
    - user: root
    - group: root
    - require:
      - file: plex-monitoring-project
      - cmd: setup-plex-monitoring-env

plex-monitoring-symlink:
  file.symlink:
    - name: /etc/zabbix/bin/plex_monitor.py
    - target: /opt/plex-monitoring/plex_monitor.py
    - require:
      - file: plex-monitoring-script
      - file: plex-monitoring-directory

plex-maintenance-monitoring-symlink:
  file.symlink:
    - name: /etc/zabbix/bin/plex_maintenance_monitor.py
    - target: /opt/plex-monitoring/plex_maintenance_monitor.py
    - require:
      - file: plex-maintenance-monitoring-script
      - file: plex-monitoring-directory

plex-zabbix-config:
  file.managed:
    - name: /etc/zabbix/zabbix_agent2.d/plex.conf
    - source: salt://application/plex/files/plex.conf
    - mode: '0644'
    - user: root
    - group: root
    - watch_in:
      - service: zabbix-agent2
    - require:
      - file: plex-monitoring-symlink
      - file: plex-maintenance-monitoring-symlink

plex-monitoring-update:
  file.managed:
    - name: /opt/plex-monitoring/update.sh
    - mode: '0755'
    - contents: |
        #!/bin/bash
        # Update Plex monitoring dependencies
        cd /opt/plex-monitoring
        /root/.cargo/bin/uv sync
        /root/.cargo/bin/uv add --upgrade requests
    - require:
      - cmd: setup-plex-monitoring-env

test-plex-monitoring:
  cmd.run:
    - name: /etc/zabbix/bin/plex_monitor.py "{{ plex_url }}" "{{ plex_token }}" "active_sessions"
    - require:
      - file: plex-monitoring-symlink
    - unless: test -z "{{ plex_token }}"

test-plex-maintenance-monitoring:
  cmd.run:
    - name: /etc/zabbix/bin/plex_maintenance_monitor.py backup_age
    - require:
      - file: plex-maintenance-monitoring-symlink
