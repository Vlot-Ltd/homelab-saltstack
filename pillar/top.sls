base:
  '*':
    - common.schedule
    - common.hosts
    - application.zabbixagent
  'docker':
    - application.linkwarden
    - application.webdriver
  'netbox':
    - application.netbox
  'nlremote*':
    - nlremote
  'plex':
    - application.plex
  'postgres':
    - postgres
    - application.netbox
    - application.linkwarden
    - application.zabbix
  'zabbix':
    - application.zabbix
    - application.grafana
