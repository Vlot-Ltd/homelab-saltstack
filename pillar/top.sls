base:
  '*':
    - common.schedule
    - common.hosts
    - application.zabbixagent
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
