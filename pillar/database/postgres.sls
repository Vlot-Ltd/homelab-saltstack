postgres_monitoring_users:
  - name_key: zabbix_monitor_user
    password_key: zabbix_monitor_password

backup_nfs_server: 192.168.0.3
backup_nfs_path: /mnt/backuppool/postgres

postgres_maintenance:
  autovacuum: True
  analyze: True
  reindex: True
  schedule: daily
