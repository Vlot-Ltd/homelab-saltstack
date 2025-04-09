include:
  - .repo

zabbix-agent2:
  pkgs.installed:
    - require:
        - pkg: install-zabbix-release

zabbix-agent2-config:
  file.managed:
    - name: /etc/zabbix/zabbix_agent2.conf
    - source: salt://zabbix/files/zabbix_agent2.conf.jinja
    - mode: "0644"
    - require:
        - pkg: zabbix-agent2

zabbix-agent2-service:
  service.running:
    - name: zabbix-agent2
    - enable: True
    - require:
        - file: zabbix-agent2-config
