grafana_admin_password: "{{ pillar.get('grafana_password') }}"

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
      password: "{{ pillar.get('zabbix_password') }}"

  - name: ZabbixDB
    type: "postgres"
    access: "proxy"
    url: "postgres:5432"
    database: "zabbix"
    user: "zabbix_user"
    secureJsonData:
      password: "{{ pillar.get('zabbix_password') }}"
    jsonData:
      sslmode: "disable"
