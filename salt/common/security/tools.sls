# Security scanning tools installation

# Install Node.js (required for SAF CLI)
# Use Ubuntu's default Node.js for better compatibility with 24.04
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

# Install Chef InSpec using direct download (most reliable)
inspec_ruby:
  pkg.installed:
    - names:
      - ruby
      - ruby-dev
      - build-essential
      - curl

inspec_download:
  cmd.run:
    - name: |
        curl -L https://omnitruck.chef.io/install.sh | bash -s -- -P inspec
    - creates: /usr/bin/inspec
    - require:
      - pkg: inspec_ruby

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
    - source: https://github.com/zaproxy/zaproxy/releases/download/v2.15.0/ZAP_2.15.0_Linux.tar.gz
    - source_hash: sha256=6410e196baab458a9204e29aafb5745fca003a2a6c0386f2c6e5c04b67621fa7
    - archive_format: tar
    - enforce_toplevel: False
    - user: root
    - group: root

# Create ZAP symlink
zap_symlink:
  file.symlink:
    - name: /usr/local/bin/zap.sh
    - target: /opt/zap/ZAP_2.15.0/zap.sh
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