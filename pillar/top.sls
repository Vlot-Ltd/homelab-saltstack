base:
  '*':
    - common.schedule
    - common.hosts
    - common.timesync
    - application.zabbixagent
    - application.docker
    - common.security
    - common.vault_secrets
  'docker':
    - application.linkwarden
    - application.heimdall2
    - application.homepage
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
