#!/opt/plex-monitoring/.venv/bin/python
"""
Plex maintenance monitoring script for Zabbix
Monitors backup status, database health, disk usage, and update status
"""
import sys
import os
import json
import sqlite3
import subprocess
from datetime import datetime, timedelta
from pathlib import Path

class PlexMaintenanceMonitor:
    """
    Monitor Plex maintenance operations and system health.
    
    Provides monitoring for:
    - Backup status and age
    - Database size and integrity
    - Disk usage
    - Update availability
    - Log file analysis
    """
    
    def __init__(self, plex_data_dir="/var/lib/plexmediaserver", backup_dir="/backups/plex"):
        """
        Initialize maintenance monitor.
        
        Args:
            plex_data_dir (str): Plex data directory path
            backup_dir (str): Backup directory path
        """
        self.plex_data_dir = Path(plex_data_dir)
        self.backup_dir = Path(backup_dir)
        self.db_path = self.plex_data_dir / "Library/Application Support/Plex Media Server/Plug-in Support/Databases/com.plexapp.plugins.library.db"
        
    def get_last_backup_age(self):
        """Get age of last backup in hours."""
        try:
            backup_files = list(self.backup_dir.glob("plex_backup_*.tar.gz"))
            if not backup_files:
                return -1  # No backups found
            
            latest_backup = max(backup_files, key=lambda x: x.stat().st_mtime)
            backup_time = datetime.fromtimestamp(latest_backup.stat().st_mtime)
            age_hours = (datetime.now() - backup_time).total_seconds() / 3600
            
            return int(age_hours)
        except (OSError, ValueError) as e:
            print(f"Error checking backup age: {e}", file=sys.stderr)
            return -1
    
    def get_backup_count(self):
        """Get number of backup files."""
        try:
            backup_files = list(self.backup_dir.glob("plex_backup_*.tar.gz"))
            return len(backup_files)
        except OSError:
            return 0
    
    def get_backup_size_total(self):
        """Get total size of all backups in MB."""
        try:
            backup_files = list(self.backup_dir.glob("plex_backup_*.tar.gz"))
            total_size = sum(f.stat().st_size for f in backup_files)
            return int(total_size / (1024 * 1024))  # Convert to MB
        except OSError:
            return 0
    
    def get_database_size(self):
        """Get Plex database size in MB."""
        try:
            if self.db_path.exists():
                size_bytes = self.db_path.stat().st_size
                return int(size_bytes / (1024 * 1024))  # Convert to MB
            return 0
        except OSError:
            return 0
    
    def check_database_integrity(self):
        """Check database integrity (0=ok, 1=error)."""
        try:
            if not self.db_path.exists():
                return 1
            
            conn = sqlite3.connect(str(self.db_path))
            cursor = conn.cursor()
            cursor.execute("PRAGMA integrity_check;")
            result = cursor.fetchone()[0]
            conn.close()
            
            return 0 if result == "ok" else 1
        except (sqlite3.Error, OSError) as e:
            print(f"Database integrity check failed: {e}", file=sys.stderr)
            return 1
    
    def get_plex_disk_usage(self):
        """Get disk usage percentage for Plex data directory."""
        try:
            result = subprocess.run(
                ['df', str(self.plex_data_dir)],
                capture_output=True,
                text=True,
                check=True
            )
            lines = result.stdout.strip().split('\n')
            if len(lines) >= 2:
                usage_line = lines[1].split()
                usage_percent = int(usage_line[4].rstrip('%'))
                return usage_percent
            return 0
        except (subprocess.CalledProcessError, ValueError, IndexError):
            return 0
    
    def get_cache_size(self):
        """Get cache directory size in MB."""
        try:
            cache_dir = self.plex_data_dir / "Library/Application Support/Plex Media Server/Cache"
            if not cache_dir.exists():
                return 0
            
            result = subprocess.run(
                ['du', '-sm', str(cache_dir)],
                capture_output=True,
                text=True,
                check=True
            )
            size_mb = int(result.stdout.split()[0])
            return size_mb
        except (subprocess.CalledProcessError, ValueError):
            return 0
    
    def check_log_errors(self, log_file, hours=24):
        """Check for errors in log file within specified hours."""
        try:
            log_path = Path(log_file)
            if not log_path.exists():
                return 0
            
            cutoff_time = datetime.now() - timedelta(hours=hours)
            error_count = 0
            
            with open(log_path, 'r') as f:
                for line in f:
                    if 'ERROR' in line.upper() or 'FAILED' in line.upper():
                        # Simple date parsing - adjust based on your log format
                        try:
                            # Assuming log format has timestamp at beginning
                            if cutoff_time.strftime('%Y-%m-%d') in line:
                                error_count += 1
                        except:
                            # If date parsing fails, count all errors
                            error_count += 1
            
            return error_count
        except (OSError, IOError):
            return 0
    
    def get_service_uptime(self):
        """Get Plex service uptime in hours."""
        try:
            result = subprocess.run(
                ['systemctl', 'show', 'plexmediaserver', '--property=ActiveEnterTimestamp'],
                capture_output=True,
                text=True,
                check=True
            )
            
            timestamp_line = result.stdout.strip()
            if 'ActiveEnterTimestamp=' in timestamp_line:
                timestamp_str = timestamp_line.split('=', 1)[1]
                if timestamp_str and timestamp_str != 'n/a':
                    # Parse systemd timestamp format
                    start_time = datetime.strptime(timestamp_str.split()[0] + ' ' + timestamp_str.split()[1], '%Y-%m-%d %H:%M:%S')
                    uptime_hours = (datetime.now() - start_time).total_seconds() / 3600
                    return int(uptime_hours)
            
            return 0
        except (subprocess.CalledProcessError, ValueError, IndexError):
            return 0
    
    def check_update_available(self):
        """Check if Plex update is available (0=no, 1=yes)."""
        try:
            # Get current version
            result = subprocess.run(
                ['dpkg', '-l', 'plexmediaserver'],
                capture_output=True,
                text=True,
                check=True
            )
            
            current_version = None
            for line in result.stdout.split('\n'):
                if 'plexmediaserver' in line:
                    current_version = line.split()[2]
                    break
            
            if not current_version:
                return 0
            
            # Check latest version (this is a simplified check)
            # In production, you'd want to call the Plex API properly
            update_log = Path('/var/log/plex_update.log')
            if update_log.exists():
                with open(update_log, 'r') as f:
                    content = f.read()
                    if 'Update available' in content and datetime.now().strftime('%Y-%m-%d') in content:
                        return 1
            
            return 0
        except (subprocess.CalledProcessError, OSError):
            return 0

def main():
    """
    Main function for Plex maintenance monitoring.
    
    Usage:
        plex_maintenance_monitor.py <metric> [data_dir] [backup_dir]
        
    Metrics:
        backup_age - Age of last backup in hours
        backup_count - Number of backup files
        backup_size - Total backup size in MB
        db_size - Database size in MB
        db_integrity - Database integrity (0=ok, 1=error)
        disk_usage - Disk usage percentage
        cache_size - Cache directory size in MB
        backup_errors - Error count in backup log (24h)
        maintenance_errors - Error count in maintenance log (24h)
        update_errors - Error count in update log (24h)
        service_uptime - Service uptime in hours
        update_available - Update available (0=no, 1=yes)
    """
    if len(sys.argv) < 2:
        print("Usage: plex_maintenance_monitor.py <metric> [data_dir] [backup_dir]", file=sys.stderr)
        print("Metrics: backup_age, backup_count, backup_size, db_size, db_integrity,", file=sys.stderr)
        print("         disk_usage, cache_size, backup_errors, maintenance_errors,", file=sys.stderr)
        print("         update_errors, service_uptime, update_available", file=sys.stderr)
        sys.exit(1)
    
    metric = sys.argv[1]
    data_dir = sys.argv[2] if len(sys.argv) > 2 else "/var/lib/plexmediaserver"
    backup_dir = sys.argv[3] if len(sys.argv) > 3 else "/backups/plex"
    
    monitor = PlexMaintenanceMonitor(data_dir, backup_dir)
    
    try:
        if metric == 'backup_age':
            print(monitor.get_last_backup_age())
        elif metric == 'backup_count':
            print(monitor.get_backup_count())
        elif metric == 'backup_size':
            print(monitor.get_backup_size_total())
        elif metric == 'db_size':
            print(monitor.get_database_size())
        elif metric == 'db_integrity':
            print(monitor.check_database_integrity())
        elif metric == 'disk_usage':
            print(monitor.get_plex_disk_usage())
        elif metric == 'cache_size':
            print(monitor.get_cache_size())
        elif metric == 'backup_errors':
            print(monitor.check_log_errors('/var/log/plex_backup.log'))
        elif metric == 'maintenance_errors':
            print(monitor.check_log_errors('/var/log/plex_maintenance.log'))
        elif metric == 'update_errors':
            print(monitor.check_log_errors('/var/log/plex_update.log'))
        elif metric == 'service_uptime':
            print(monitor.get_service_uptime())
        elif metric == 'update_available':
            print(monitor.check_update_available())
        else:
            print(f"Unknown metric: {metric}", file=sys.stderr)
            sys.exit(1)
    
    except Exception as e:
        print(f"Error executing metric '{metric}': {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    main()