include:
  - application.zabbix

zabbix-server-packages:
  pkg.installed:
    - names:
        - zabbix-server-pgsql
        - zabbix-frontend-php
        - zabbix-sql-scripts
        - php8.3-pgsql
        - zabbix-apache-conf
    - require:
        - pkg: install-zabbix-release

zabbix-db-config:
  file.managed:
    - name: /etc/zabbix/zabbix_server.conf
    - source: salt://application/zabbix/files/zabbix_server.conf.jinja
    - template: jinja
    - mode: "0644"
    - require:
        - pkg: zabbix-server-packages

zabbix-server-service:
  service.running:
    - name: zabbix-server
    - enable: True
    - watch:
      - file: zabbix-db-config
    - require:
      - file: zabbix-db-config

apache2.service:
  service.running:
    - enable: True
    - require:
        - pkg: zabbix-server-packages

locales-pkg:
  pkg.installed:
    - name: locales

generate-locales:
  cmd.run:
    - name: locale-gen en_GB.UTF-8 en_GB en_US.UTF-8 en_US
    - unless: locale -a | egrep "GB|US"
    - require:
      - pkg: locales-pkg

set_engb_locale:
  cmd.run:
    - name: localectl set-locale LANG=en_GB.UTF-8
    - unless: grep en_GB.UTF-8 /etc/locale.conf
    - require:
      - cmd: generate-locales
