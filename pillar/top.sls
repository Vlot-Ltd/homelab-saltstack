base:
  '*':
    - common.schedule
    - common.hosts
  'postgres':
    - postgres
    - application.netbox
    - application.linkwarden
    - application.zabbix
  'docker':
    - application.linkwarden
    - application.netbox
  'zabbix':
    - application.zabbix
    - application.grafana
