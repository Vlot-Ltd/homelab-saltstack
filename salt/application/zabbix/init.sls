include:
  - .repo

zabbix-agent-packages:
  pkg.installed:
    - pkgs:
      - facter
    - require:
      - pkg: install-zabbix-release

{#- latest, not installed: a release-package change (e.g. 8.0 beta -> GA)
    upgrades the agent on the next highstate (PEP-HL-SLT-031). #}
zabbix-agent-latest:
  pkg.latest:
    - pkgs:
      - zabbix-agent2
      - zabbix-sender
    - refresh: True
    - require:
      - pkg: install-zabbix-release
    - require_in:
      - file: zabbix-agent2-config
    - watch_in:
      - service: zabbix-agent2-service

zabbix-agent2-config:
  file.managed:
    - name: /etc/zabbix/zabbix_agent2.conf
    - source: salt://application/zabbix/files/zabbix_agent2.conf.jinja
    - template: jinja
    - mode: "0644"
    - require:
      - pkg: zabbix-agent-packages

zabbix-agent2-service:
  service.running:
    - name: zabbix-agent2
    - enable: True
    - watch:
      - file: zabbix-agent2-config
    - require:
      - pkg: zabbix-agent-packages
