grafana_admin_password: "SuperSecureGrafanaPass"

grafana_datasources:
  - name: Zabbix
    type: "alexanderzobnin-zabbix-datasource"
    access: "proxy"
    url: "http://localhost/zabbix/api_jsonrpc.php"
    isDefault: true
    jsonData:
      username: "Admin"
      trends: true
      trendsFrom: "7d"
      trendsRange: "4d"
      cacheTTL: "30s"
      timeout: 30
      directDbConnection:
        enabled: true
        dataSource: "ZabbixDB"
    secureJsonData:
      password: "zabbix"

  - name: ZabbixDB
    type: "postgres"
    access: "proxy"
    url: "postgres:5432"
    database: "zabbix"
    user: "zabbix_user"
    secureJsonData:
      password: "ZabbixP@ss"
    jsonData:
      sslmode: "disable"
