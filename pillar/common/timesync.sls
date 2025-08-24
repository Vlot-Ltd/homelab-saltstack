# Time synchronization configuration
# Default timezone for all systems
timezone: UTC

# Primary NTP servers (customize for your region)
ntp_servers:
  - 0.ubuntu.pool.ntp.org
  - 1.ubuntu.pool.ntp.org  
  - 2.ubuntu.pool.ntp.org
  - 3.ubuntu.pool.ntp.org

# Fallback NTP servers
fallback_ntp_servers:
  - time.cloudflare.com
  - time.google.com
  - pool.ntp.org

# NTP configuration parameters
ntp_root_distance_max: '5'
ntp_poll_min: '32'
ntp_poll_max: '2048'
ntp_connection_retry: '30'

# Per-host timezone overrides
# Example: if a system needs a different timezone
host_timezones:
  nlremote: 'Europe/Amsterdam'