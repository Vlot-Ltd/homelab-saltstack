grafana_admin_password: "SuperSecureGrafanaPass"

grafana_datasources:
  - name: Zabbix
    type: "alexanderzobnin-zabbix-datasource"
    access: "proxy"
    url: "http://localhost/zabbix/api_jsonrpc.php"
    jsonData:
      username: "Admin"
    secureJsonData:
      password: "zabbix"

  - name: PostgreSQL
    type: "postgres"
    access: "proxy"
    url: "postgres:5432"
    database: "zabbix"
    user: "zabbix_user"
    secureJsonData:
      password: "ZabbixP@ss!"
    jsonData:
      sslmode: "disable"
