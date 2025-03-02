include:
  - application.zabbix

zabbix-packages:
  pkg.installed:
    - names:
        - zabbix-server-pgsql
        - zabbix-frontend-php
        - zabbix-agent
    - require:
        - cmd: zabbix-repo

zabbix-db-config:
  file.managed:
    - name: /etc/zabbix/zabbix_server.conf
    - source: salt://zabbix/files/zabbix_server.conf.jinja
    - mode: "0644"
    - require:
        - pkg: zabbix-packages

zabbix-service:
  service.running:
    - name: zabbix-server
    - enable: True
    - require:
        - file: zabbix-db-config