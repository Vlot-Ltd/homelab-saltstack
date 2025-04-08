base:
  '*':
    - common
  'kernel:Linux':
    - match: grain
    - os.linux.base_linux
    - os.linux.install_vim
  'os:MacOS':
    - match: grain
    - os.mac.brew_update
  'cpuarch:aarch64':
    - match: grain
    - hardware.pi
  'virtual:kvm':
    - match: grain
    - os.linux.install_qemu_agent
  'docker':
    - application.docker
    - application.linkwarden
    - application.netbox
  'postgres':
    - database.postgres
  'zabbix':
    - application.zabbix.server
