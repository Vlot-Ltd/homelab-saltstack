backup-nfs-mount:
  pkg.installed:
    - name: nfs-common

  file.directory:
    - name: /backups
    - makedirs: True

  mount.mounted:
    - name: /backups
    - device: {{ salt['pillar.get']('backup_nfs_server') }}:{{ salt['pillar.get']('backup_nfs_path') }}
    - fstype: nfs
    - opts: defaults
    - persist: True
    - require:
      - pkg: nfs-common
      - file: /backups

postgres-backup-script:
  file.managed:
    - name: /usr/local/bin/postgres_backup.sh
    - source: salt://database/postgres/files/postgres_backup.sh
    - mode: '0755'
    - user: root
    - group: root
    - require:
      - mount: /backups

postgres-backup-cron:
  pkg.installed:
    - name: cron
    - require:
      - postgres-backup-script

  service.running:
    - name: cron
    - enable: True
    - require:
      - pkg: cron

  cron.present:
    - name: /usr/local/bin/postgres_backup.sh
    - user: postgres
    - minute: '0'
    - hour: '2'
    - comment: "Daily PostgreSQL backup at 2 AM"
    - require:
      - file: /usr/local/bin/postgres_backup.sh
      - service: cron