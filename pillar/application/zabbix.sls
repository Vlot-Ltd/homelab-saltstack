postgres_databases:
  - name: zabbix
    users:
      - name_key: zabbix_db_user
        password_key: zabbix_db_password

zabbix_server:
  StartSNMPTrappers: 0
  ValueCacheSize: '1G'
  WebDriverURL: '192.168.0.20'
