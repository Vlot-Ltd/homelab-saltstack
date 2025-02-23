backup-nfs-mount:
  pkg.installed:
    - name: nfs-common

  mount.mounted:
    - name: /backups
    - device: {{ salt['pillar.get']('backup_nfs_server') }}:{{ salt['pillar.get']('backup_nfs_path') }}
    - fstype: nfs
    - opts: defaults
    - persist: True

postgres-backup-script:
  file.managed:
    - name: /usr/local/bin/postgres_backup.sh
    - source: salt://postgres/files/postgres_backup.sh
    - mode: '0755'
    - user: root
    - group: root
    - require:
      - mount: /backups

postgres-backup-cron:
  cron.present:
    - name: /usr/local/bin/postgres_backup.sh
    - user: postgres
    - minute: '0'
    - hour: '2'
    - comment: "Daily PostgreSQL backup at 2 AM"