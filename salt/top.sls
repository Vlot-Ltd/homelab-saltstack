# Served to the master via gitfs from origin/main (PEP-HL-SLT-010).
base:
  '*':
    - common
  'kernel:Linux':
    - match: grain
    - os.linux
    - application.zabbix   # agent2; re-enabled 2026-10-17 (PEP-HL-SLT-031), works on Debian now
  'os:MacOS':
    - match: grain
    - os.mac.brew_update
  'virtual:kvm':
    - match: grain
    - os.linux.qemu_agent
  'docker':
    - application.docker
    - application.fing
    - application.heimdall2
    - application.homepage
    - application.linkwarden
    - application.webdriver
    - application.prometheus
    - application.loki
  'salt':
    - application.salt-master
  'postgres':
    - database.postgres
    - application.zabbix.database
  'vault':
    - application.vault
  'zabbix':
    - application.zabbix.server
    - application.grafana.datasource-prometheus
    - application.grafana.datasource-homeassistant
