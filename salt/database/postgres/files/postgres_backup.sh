#!/bin/bash
BACKUP_DIR="/backups/postgresql"
mkdir -p "$BACKUP_DIR"
DATE=$(date +"%Y-%m-%d")
sudo -u postgres pg_dumpall > "$BACKUP_DIR/postgres_backup_$DATE.sql"
find "$BACKUP_DIR" -type f -mtime +7 -delete