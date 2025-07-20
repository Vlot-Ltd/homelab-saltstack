postgres_monitoring_users:
  - name: zabbixmonitor
    password: m0nitor!

backup_nfs_server: 192.168.0.22
backup_nfs_path: /mnt/backuppool/postgres

postgres_maintenance:
  autovacuum: True
  analyze: True
  reindex: True
  schedule: daily