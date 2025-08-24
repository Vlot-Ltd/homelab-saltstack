base:
  '*':
    - common
  'kernel:Linux':
    - match: grain
    - os.linux
    #- application.zabbix
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
  'postgres':
    - database.postgres
    - application.zabbix.database
  'vault':
    - application.vault
  'zabbix':
    - application.zabbix.server
