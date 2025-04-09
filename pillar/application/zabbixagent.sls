zabbix_agent:
  Include:
    - /etc/zabbix/zabbix_agent2.d/*.conf
    - /etc/zabbix/zabbix_agent2.d/plugins.d/*.conf
  Server: zabbix.local
  ServerActive: zabbix.local
