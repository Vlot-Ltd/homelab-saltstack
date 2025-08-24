# Security scanning tools installation

# Install Node.js (required for SAF CLI)
nodejs_repo:
  pkgrepo.managed:
    - name: deb https://deb.nodesource.com/node_18.x {{ grains['oscodename'] }} main
    - key_url: https://deb.nodesource.com/gpgkey/nodesource.gpg.key
    - require_in:
      - pkg: nodejs

nodejs:
  pkg.installed:
    - names:
      - nodejs
      - npm

# Install SAF CLI globally
saf_cli:
  npm.installed:
    - name: '@mitre/saf'
    - require:
      - pkg: nodejs

# Install Chef InSpec
chef_inspec_repo:
  pkgrepo.managed:
    - name: deb https://packages.chef.io/repos/apt/stable {{ grains['oscodename'] }} main
    - key_url: https://packages.chef.io/chef.asc
    - require_in:
      - pkg: inspec

inspec:
  pkg.installed:
    - name: inspec

# Create security scanning directory
security_scan_directory:
  file.directory:
    - name: /opt/security-scans
    - user: root
    - group: root
    - mode: '0755'
    - makedirs: True

# Create results directory
security_results_directory:
  file.directory:
    - name: /opt/security-scans/results
    - user: root
    - group: root
    - mode: '0755'
    - makedirs: True
    - require:
      - file: security_scan_directory

# Create scripts directory
security_scripts_directory:
  file.directory:
    - name: /opt/security-scans/scripts
    - user: root
    - group: root
    - mode: '0755'
    - makedirs: True
    - require:
      - file: security_scan_directory

# Create profiles directory
security_profiles_directory:
  file.directory:
    - name: /opt/security-scans/profiles
    - user: root
    - group: root
    - mode: '0755'
    - makedirs: True
    - require:
      - file: security_scan_directory

# Install OWASP ZAP (for web application scanning)
owasp_zap:
  archive.extracted:
    - name: /opt/zap
    - source: https://github.com/zaproxy/zaproxy/releases/download/v2.14.0/ZAP_2.14.0_Linux.tar.gz
    - source_hash: sha256=c7c5b7b3e8d6d2e1f3c4a5b6e7f8g9h0i1j2k3l4m5n6o7p8q9r0s1t2u3v4w5x6
    - archive_format: tar
    - enforce_toplevel: False
    - user: root
    - group: root

# Create ZAP symlink
zap_symlink:
  file.symlink:
    - name: /usr/local/bin/zap.sh
    - target: /opt/zap/ZAP_2.14.0/zap.sh
    - require:
      - archive: owasp_zap

# Install additional security tools
security_packages:
  pkg.installed:
    - names:
      - nmap
      - nikto
      - lynis
      - rkhunter
      - chkrootkit
      - aide
      - clamav
      - clamav-daemon