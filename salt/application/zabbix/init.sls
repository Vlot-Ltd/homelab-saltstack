include:
  - .repo

zabbix-agent-packages:
  pkg.installed:
    - pkgs:
      - zabbix-agent2
      - zabbix-sender
      - facter
    - require:
      - pkg: install-zabbix-release

zabbix-agent2-config:
  file.managed:
    - name: /etc/zabbix/zabbix_agent2.conf
    - source: salt://application/zabbix/files/zabbix_agent2.conf.jinja
    - template: jinja
    - mode: "0644"
    - require:
      - pkg: zabbix-agent2

zabbix-agent2-service:
  service.running:
    - name: zabbix-agent2
    - enable: True
    - watch:
      - file: zabbix-agent2-config
    - require:
      - pkg: zabbix-agent2
