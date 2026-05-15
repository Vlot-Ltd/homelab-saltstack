grafana_datasources:
  - name: Zabbix
    type: "alexanderzobnin-zabbix-datasource"
    access: "proxy"
    url: "http://localhost/zabbix/api_jsonrpc.php"
    isDefault: true
    jsonData:
      username_key: "zabbix_api_user"
      trends: true
      trendsFrom: "7d"
      trendsRange: "4d"
      cacheTTL: "30s"
      timeout: 30
      directDbConnection:
        enabled: true
        dataSource: "ZabbixDB"
    secureJsonData:
      password_key: "zabbix_api_password"

  - name: ZabbixDB
    type: "postgres"
    access: "proxy"
    url: "postgres:5432"
    database: "zabbix"
    user_key: "zabbix_db_user"
    secureJsonData:
      password_key: "zabbix_db_password"
    jsonData:
      sslmode: "disable"
