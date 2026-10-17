zabbix_agent:
  Include:
    - /etc/zabbix/zabbix_agent2.d/*.conf
    - /etc/zabbix/zabbix_agent2.d/plugins.d/*.conf
  # Passive checks come from the LAN address (zabbix.local, 192.168.0.23) or,
  # for hosts the server reaches over Tailscale (friday, proxmox), from its
  # Tailscale address. IP, not MagicDNS, so the agent needs no DNS at startup.
  Server: zabbix.local,100.107.102.4
  ServerActive: zabbix.local
