base:
  '*':
    - common.schedule
    - common.hosts
    - common.timesync
    - application.zabbixagent
    - common.security
  'docker':
    - application.linkwarden
    - application.heimdall2
  'netbox':
    - application.netbox
  'nlremote*':
    - nlremote
  'plex':
    - application.plex
  'postgres':
    - database.postgres
    - application.netbox
    - application.linkwarden
    - application.zabbix
    - application.heimdall2
  'zabbix':
    - application.zabbix
    - application.grafana
