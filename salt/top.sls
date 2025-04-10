base:
  '*':
    - common
  'kernel:Linux':
    - match: grain
    - os.linux.base_linux
    - os.linux.install_vim
    - application.zabbix
  'os:MacOS':
    - match: grain
    - os.mac.brew_update
  'virtual:kvm':
    - match: grain
    - os.linux.install_qemu_agent
  'docker':
    - application.docker
    - application.linkwarden
    - application.netbox
  'postgres':
    - database.postgres
    - application.zabbix.database
  'zabbix':
    - application.zabbix.server
