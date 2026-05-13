postgres_databases:
  - name: zabbix
    users:
      - name: zabbix_user
        password: "{{ pillar.get('zabbix_password') }}"

zabbix_server:
  StartSNMPTrappers: 0
  ValueCacheSize: '1G'
  WebDriverURL: '192.168.0.20'
