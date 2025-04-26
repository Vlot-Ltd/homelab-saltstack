/etc/zabbix/bin:
  file.directory:
    - user: root
    - group: root
    - dir_mode: '0755'
    - file_mode: '0755'
    - recurse:
      - user
      - group
      - mode

/etc/zabbix/bin/zabbix_pi.sh:
  file.managed:
    - user: root
    - group: root
    - mode: '0755'
    - source: salt://hardware/pi/files/zabbix_pi.sh

/etc/zabbix/zabbix_agent2.d/zabbix_pi.conf:
  file.managed:
    - user: root
    - group: root
    - mode: '0755'
    - source: salt://hardware/pi/files/zabbix_pi.conf
