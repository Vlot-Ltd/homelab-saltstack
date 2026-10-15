# Served to the master via git_pillar from origin/main (PEP-HL-SLT-010).
base:
  '*':
    - common.schedule
    - common.hosts
    - common.timesync
    - application.zabbixagent
    - application.docker
    - common.security
  'docker':
    - application.linkwarden
    - application.heimdall2
    - application.homepage
    - database.roles
    - monitoring.roles
  'nlremote*':
    - nlremote
  'plex':
    - application.plex
  'postgres':
    - database.postgres
    - database.roles
    - application.linkwarden
    - application.zabbix
    - application.heimdall2
    - application.manyfold
  'zabbix':
    - application.zabbix
    - application.grafana
    - database.roles
    - monitoring.roles
