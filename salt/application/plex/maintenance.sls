# salt/application/plex/maintenance.sls
{% set plex_user = salt['pillar.get']('plex_user', 'plex') %}
{% set plex_data_dir = salt['pillar.get']('plex_data_dir', '/var/lib/plexmediaserver') %}
{% set plex_backup_dir = salt['pillar.get']('plex_backup_dir', '/backups/plex') %}
{% set plex_auto_update = salt['pillar.get']('plex_auto_update', True) %}
{% set plex_beta_updates = salt['pillar.get']('plex_beta_updates', False) %}
{% set backup_retention_days = salt['pillar.get']('plex_backup_retention', 30) %}

include:
  - .monitoring

# Create backup directory
plex-backup-directory:
  file.directory:
    - name: {{ plex_backup_dir }}
    - user: {{ plex_user }}
    - group: {{ plex_user }}
    - mode: '0755'
    - makedirs: True

# Plex database backup script
plex-backup-script:
  file.managed:
    - name: /usr/local/bin/plex_backup.sh
    - mode: '0755'
    - user: root
    - group: root
    - contents: |
        #!/bin/bash
        # Plex Media Server backup script
        
        PLEX_DATA_DIR="{{ plex_data_dir }}"
        BACKUP_DIR="{{ plex_backup_dir }}"
        DATE=$(date +%Y%m%d_%H%M%S)
        BACKUP_FILE="$BACKUP_DIR/plex_backup_$DATE.tar.gz"
        LOG_FILE="/var/log/plex_backup.log"
        
        echo "$(date): Starting Plex backup" >> $LOG_FILE
        
        # Stop Plex service
        systemctl stop plexmediaserver.service
        sleep 5
        
        # Create backup (exclude cache and logs)
        tar -czf "$BACKUP_FILE" \
            --exclude="$PLEX_DATA_DIR/Library/Application Support/Plex Media Server/Cache" \
            --exclude="$PLEX_DATA_DIR/Library/Application Support/Plex Media Server/Logs" \
            --exclude="$PLEX_DATA_DIR/Library/Application Support/Plex Media Server/Crash Reports" \
            -C "$(dirname $PLEX_DATA_DIR)" \
            "$(basename $PLEX_DATA_DIR)" 2>>$LOG_FILE
        
        # Start Plex service
        systemctl start plexmediaserver.service
        
        if [ $? -eq 0 ]; then
            echo "$(date): Backup completed successfully: $BACKUP_FILE" >> $LOG_FILE
            # Clean old backups
            find "$BACKUP_DIR" -name "plex_backup_*.tar.gz" -mtime +{{ backup_retention_days }} -delete
            echo "$(date): Old backups cleaned (>{{ backup_retention_days }} days)" >> $LOG_FILE
        else
            echo "$(date): Backup failed!" >> $LOG_FILE
            exit 1
        fi
    - require:
      - file: plex-backup-directory

# Plex database maintenance script
plex-maintenance-script:
  file.managed:
    - name: /usr/local/bin/plex_maintenance.sh
    - mode: '0755'
    - user: root
    - group: root
    - contents: |
        #!/bin/bash
        # Plex Media Server maintenance script
        
        PLEX_DATA_DIR="{{ plex_data_dir }}"
        DB_PATH="$PLEX_DATA_DIR/Library/Application Support/Plex Media Server/Plug-in Support/Databases/com.plexapp.plugins.library.db"
        LOG_FILE="/var/log/plex_maintenance.log"
        
        echo "$(date): Starting Plex maintenance" >> $LOG_FILE
        
        # Stop Plex service
        systemctl stop plexmediaserver.service
        sleep 5
        
        # Database maintenance
        if [ -f "$DB_PATH" ]; then
            echo "$(date): Running database VACUUM" >> $LOG_FILE
            sqlite3 "$DB_PATH" "VACUUM;" 2>>$LOG_FILE
            
            echo "$(date): Running database REINDEX" >> $LOG_FILE
            sqlite3 "$DB_PATH" "REINDEX;" 2>>$LOG_FILE
            
            echo "$(date): Running database integrity check" >> $LOG_FILE
            INTEGRITY_CHECK=$(sqlite3 "$DB_PATH" "PRAGMA integrity_check;")
            if [ "$INTEGRITY_CHECK" != "ok" ]; then
                echo "$(date): Database integrity check failed: $INTEGRITY_CHECK" >> $LOG_FILE
            else
                echo "$(date): Database integrity check passed" >> $LOG_FILE
            fi
        fi
        
        # Clean cache directories
        echo "$(date): Cleaning cache directories" >> $LOG_FILE
        find "$PLEX_DATA_DIR/Library/Application Support/Plex Media Server/Cache" -type f -mtime +7 -delete 2>>$LOG_FILE
        find "$PLEX_DATA_DIR/Library/Application Support/Plex Media Server/Logs" -name "*.log" -mtime +30 -delete 2>>$LOG_FILE
        
        # Clean transcoding temp files
        find /tmp -name "plex-transcode-*" -mtime +1 -delete 2>>$LOG_FILE
        
        # Start Plex service
        systemctl start plexmediaserver.service
        
        echo "$(date): Plex maintenance completed" >> $LOG_FILE

# Plex update script
plex-update-script:
  file.managed:
    - name: /usr/local/bin/plex_update.sh
    - mode: '0755'
    - user: root
    - group: root
    - contents: |
        #!/bin/bash
        # Plex Media Server update script
        
        LOG_FILE="/var/log/plex_update.log"
        {% if plex_beta_updates %}
        DOWNLOAD_URL="https://plex.tv/api/downloads/5.json?channel=plexpass"
        {% else %}
        DOWNLOAD_URL="https://plex.tv/api/downloads/5.json?channel=public"
        {% endif %}
        
        echo "$(date): Checking for Plex updates" >> $LOG_FILE
        
        # Get current version
        CURRENT_VERSION=$(dpkg -l | grep plexmediaserver | awk '{print $3}')
        echo "$(date): Current version: $CURRENT_VERSION" >> $LOG_FILE
        
        # Get latest version info
        LATEST_INFO=$(curl -s "$DOWNLOAD_URL" | jq -r '.computer.Linux.version, .computer.Linux.releases[0].url' | head -2)
        LATEST_VERSION=$(echo "$LATEST_INFO" | head -1)
        DOWNLOAD_LINK=$(echo "$LATEST_INFO" | tail -1)
        
        echo "$(date): Latest version: $LATEST_VERSION" >> $LOG_FILE
        
        if [ "$CURRENT_VERSION" != "$LATEST_VERSION" ]; then
            echo "$(date): Update available, downloading..." >> $LOG_FILE
            
            # Create backup before update
            /usr/local/bin/plex_backup.sh
            
            # Download and install update
            cd /tmp
            wget -q "$DOWNLOAD_LINK" -O plex-update.deb
            
            if [ $? -eq 0 ]; then
                echo "$(date): Installing update..." >> $LOG_FILE
                dpkg -i plex-update.deb >> $LOG_FILE 2>&1
                
                # Restart service
                systemctl restart plexmediaserver.service
                
                echo "$(date): Update completed to version $LATEST_VERSION" >> $LOG_FILE
                rm -f plex-update.deb
            else
                echo "$(date): Download failed" >> $LOG_FILE
                exit 1
            fi
        else
            echo "$(date): Already up to date" >> $LOG_FILE
        fi

# Install jq for update script
jq-package:
  pkg.installed:
    - name: jq

# Log rotation for Plex logs
plex-logrotate:
  file.managed:
    - name: /etc/logrotate.d/plex-maintenance
    - mode: '0644'
    - contents: |
        /var/log/plex_backup.log
        /var/log/plex_maintenance.log
        /var/log/plex_update.log
        {
            weekly
            rotate 12
            compress
            delaycompress
            missingok
            notifempty
            create 644 root root
        }

# Scheduled backup (weekly on Sunday at 2 AM)
plex-backup-cron:
  cron.present:
    - name: /usr/local/bin/plex_backup.sh
    - user: root
    - minute: 0
    - hour: 2
    - dayweek: 0
    - comment: "Weekly Plex backup"
    - require:
      - file: plex-backup-script

# Scheduled maintenance (monthly on first Sunday at 3 AM)
plex-maintenance-cron:
  cron.present:
    - name: /usr/local/bin/plex_maintenance.sh
    - user: root
    - minute: 0
    - hour: 3
    - dayweek: 0
    - daymonth: "1-7"
    - comment: "Monthly Plex database maintenance"
    - require:
      - file: plex-maintenance-script

# Scheduled updates (if enabled)
{% if plex_auto_update %}
plex-update-cron:
  cron.present:
    - name: /usr/local/bin/plex_update.sh
    - user: root
    - minute: 0
    - hour: 4
    - dayweek: 2
    - comment: "Weekly Plex update check (Tuesday 4 AM)"
    - require:
      - file: plex-update-script
      - pkg: jq-package
{% else %}
plex-update-cron:
  cron.absent:
    - name: /usr/local/bin/plex_update.sh
    - user: root
{% endif %}

# Performance tuning script
plex-performance-tuning:
  file.managed:
    - name: /usr/local/bin/plex_performance.sh
    - mode: '0755'
    - contents: |
        #!/bin/bash
        # Plex performance optimization
        
        # Increase file limits for Plex user
        echo "{{ plex_user }} soft nofile 65536" >> /etc/security/limits.conf
        echo "{{ plex_user }} hard nofile 65536" >> /etc/security/limits.conf
        
        # Optimize systemd service
        mkdir -p /etc/systemd/system/plexmediaserver.service.d
        cat > /etc/systemd/system/plexmediaserver.service.d/override.conf << EOF
        [Service]
        LimitNOFILE=65536
        IOSchedulingClass=1
        IOSchedulingPriority=4
        EOF
        
        systemctl daemon-reload
        
        # Network optimizations
        echo 'net.core.rmem_max = 134217728' >> /etc/sysctl.conf
        echo 'net.core.wmem_max = 134217728' >> /etc/sysctl.conf
        sysctl -p
        
        echo "Plex performance optimizations applied"

# Apply performance tuning once
plex-apply-performance-tuning:
  cmd.run:
    - name: /usr/local/bin/plex_performance.sh
    - unless: grep -q "{{ plex_user }} soft nofile 65536" /etc/security/limits.conf
    - require:
      - file: plex-performance-tuning

# Health check script for monitoring
plex-health-check:
  file.managed:
    - name: /usr/local/bin/plex_health_check.sh
    - mode: '0755'
    - contents: |
        #!/bin/bash
        # Plex health check script
        
        LOG_FILE="/var/log/plex_health.log"
        
        # Check if service is running
        if ! systemctl is-active --quiet plexmediaserver.service; then
            echo "$(date): Plex service is not running, attempting restart" >> $LOG_FILE
            systemctl start plexmediaserver.service
            sleep 10
        fi
        
        # Check if web interface is responding
        if ! curl -s -o /dev/null -w "%{http_code}" http://localhost:32400/web | grep -q "200"; then
            echo "$(date): Plex web interface not responding" >> $LOG_FILE
        fi
        
        # Check disk space
        DISK_USAGE=$(df {{ plex_data_dir }} | tail -1 | awk '{print $5}' | sed 's/%//')
        if [ $DISK_USAGE -gt 90 ]; then
            echo "$(date): Warning: Disk usage is ${DISK_USAGE}%" >> $LOG_FILE
        fi

# Health check cron (every 15 minutes)
plex-health-check-cron:
  cron.present:
    - name: /usr/local/bin/plex_health_check.sh
    - user: root
    - minute: "*/15"
    - comment: "Plex health monitoring"
    - require:
      - file: plex-health-check