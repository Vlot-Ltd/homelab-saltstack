include:
  - common.security.tools

# Download CIS Ubuntu benchmark profile
cis_ubuntu_profile:
  git.latest:
    - name: https://github.com/dev-sec/cis-dil-benchmark.git
    - target: /opt/security-scans/profiles/cis-ubuntu
    - user: root
    - require:
      - file: security_profiles_directory

# Download additional security profiles
ubuntu_hardening_profile:
  git.latest:
    - name: https://github.com/dev-sec/linux-baseline.git
    - target: /opt/security-scans/profiles/linux-baseline
    - user: root
    - require:
      - file: security_profiles_directory

ssh_hardening_profile:
  git.latest:
    - name: https://github.com/dev-sec/ssh-baseline.git
    - target: /opt/security-scans/profiles/ssh-baseline
    - user: root
    - require:
      - file: security_profiles_directory

# Security scan script
security_scan_script:
  file.managed:
    - name: /opt/security-scans/scripts/run_security_scans.sh
    - source: salt://common/security/files/run_security_scans.sh.jinja
    - template: jinja
    - user: root
    - group: root
    - mode: '0755'
    - require:
      - file: security_scripts_directory

# Upload to Heimdall2 script
upload_heimdall_script:
  file.managed:
    - name: /opt/security-scans/scripts/upload_to_heimdall.py
    - source: salt://common/security/files/upload_to_heimdall.py.jinja
    - template: jinja
    - user: root
    - group: root
    - mode: '0755'
    - require:
      - file: security_scripts_directory

# Install Python requests for upload script
python_requests:
  pip.installed:
    - name: requests

# Create systemd service for automated scanning
security_scan_service:
  file.managed:
    - name: /etc/systemd/system/security-scans.service
    - source: salt://common/security/files/security-scans.service.jinja
    - template: jinja
    - user: root
    - group: root
    - mode: '0644'

# Create systemd timer for automated scanning
security_scan_timer:
  file.managed:
    - name: /etc/systemd/system/security-scans.timer
    - source: salt://common/security/files/security-scans.timer.jinja
    - template: jinja
    - user: root
    - group: root
    - mode: '0644'

# Enable and start the timer
security_scan_timer_enabled:
  service.enabled:
    - name: security-scans.timer
    - require:
      - file: security_scan_timer
      - file: security_scan_service

# Reload systemd daemon
systemd_reload:
  cmd.run:
    - name: systemctl daemon-reload
    - onchanges:
      - file: security_scan_service
      - file: security_scan_timer