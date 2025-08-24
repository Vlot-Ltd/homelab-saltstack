# Time synchronization configuration for Ubuntu/Raspbian systems

# Install time sync packages
timesyncd_package:
  pkg.installed:
    - name: systemd-timesyncd

# Remove conflicting packages
ntp_package_removed:
  pkg.removed:
    - names:
      - ntp
      - ntpsec
      - chrony

# Set timezone
timezone_set:
  timezone.system:
    - name: {{ pillar.get('timezone', grains.get('timezone', 'UTC')) }}

# Configure systemd-timesyncd (preferred for Ubuntu 16.04+)
timesyncd_config:
  file.managed:
    - name: /etc/systemd/timesyncd.conf
    - source: salt://common/files/timesyncd.conf.jinja
    - template: jinja
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - pkg: timesyncd_package

# Stop and disable conflicting services (if they exist)
ntp_service_stopped:
  service.dead:
    - name: ntp
    - enable: False
    - prereq_in:
      - service: timesyncd_service
    - onlyif: systemctl list-unit-files | grep -q ntp.service

ntpsec_service_stopped:
  service.dead:
    - name: ntpsec
    - enable: False
    - prereq_in:
      - service: timesyncd_service
    - onlyif: systemctl list-unit-files | grep -q ntpsec.service

chrony_service_stopped:
  service.dead:
    - name: chrony
    - enable: False
    - prereq_in:
      - service: timesyncd_service
    - onlyif: systemctl list-unit-files | grep -q chrony.service

# Enable and start systemd-timesyncd
timesyncd_service:
  service.running:
    - name: systemd-timesyncd
    - enable: True
    - require:
      - file: timesyncd_config
    - watch:
      - file: timesyncd_config

# Hardware clock configuration for Proxmox VMs
{% if grains.get('virtual', '') == 'kvm' or grains.get('manufacturer', '') == 'QEMU' %}
# Configure hardware clock sync for Proxmox VMs
hwclock_sync:
  file.managed:
    - name: /etc/cron.hourly/hwclock-sync
    - source: salt://common/files/hwclock-sync.sh.jinja
    - template: jinja
    - user: root
    - group: root
    - mode: '0755'

# Set hardware clock to UTC
hwclock_utc:
  cmd.run:
    - name: hwclock --systohc --utc
    - require:
      - service: timesyncd_service

# Configure adjtime for UTC hardware clock
adjtime_config:
  file.managed:
    - name: /etc/adjtime
    - contents: |
        0.0 0 0.0
        0
        UTC
    - user: root
    - group: root
    - mode: '0644'
{% endif %}

# Raspberry Pi specific configuration
{% if grains['os'] == 'Raspbian' %}
# Disable fake-hwclock on Raspberry Pi (conflicts with real time sync)
fake_hwclock_disabled:
  service.dead:
    - name: fake-hwclock
    - enable: False

# Remove fake-hwclock package if present
fake_hwclock_removed:
  pkg.removed:
    - name: fake-hwclock
    - require:
      - service: fake_hwclock_disabled
{% endif %}

# Force immediate time sync
force_time_sync:
  cmd.run:
    - name: systemctl restart systemd-timesyncd && sleep 5 && timedatectl show-timesync --all
    - require:
      - service: timesyncd_service
    - onchanges:
      - file: timesyncd_config
      - timezone: timezone_set

# Configure timedatectl settings
timedatectl_config:
  cmd.run:
    - names:
      - timedatectl set-ntp true
{% if grains.get('virtual', '') == 'kvm' or grains.get('manufacturer', '') == 'QEMU' %}
      - timedatectl set-local-rtc false
{% endif %}
    - require:
      - service: timesyncd_service