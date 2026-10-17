#!/bin/bash
# Nightly PostgreSQL backup to the NFS share. Runs as the postgres user (cron).
# One custom-format dump per database plus the cluster globals (roles, tablespaces).
# Restore: pg_restore -d <db> <file>.dump; psql -f globals_<date>.sql
set -euo pipefail

BACKUP_DIR="/backups/postgresql"
DATE=$(date +%F)
KEEP_DAYS=7

mountpoint -q /backups || { echo "/backups is not mounted" >&2; exit 1; }

pg_dumpall --globals-only > "$BACKUP_DIR/globals_$DATE.sql.tmp"
mv "$BACKUP_DIR/globals_$DATE.sql.tmp" "$BACKUP_DIR/globals_$DATE.sql"

for db in $(psql -Atc "SELECT datname FROM pg_database WHERE NOT datistemplate"); do
    pg_dump -Fc -f "$BACKUP_DIR/${db}_$DATE.dump.tmp" "$db"
    mv "$BACKUP_DIR/${db}_$DATE.dump.tmp" "$BACKUP_DIR/${db}_$DATE.dump"
done

find "$BACKUP_DIR" -type f -mtime +"$KEEP_DAYS" -delete
echo "$(date -Is) backup complete"
