install-zabbix-release:
  pkg.installed:
    - sources:
      - zabbix-release: https://repo.zabbix.com/zabbix/7.2/release/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.2+ubuntu24.04_all.deb
    - creates: /etc/apt/sources.list.d/zabbix.list
