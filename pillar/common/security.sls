# Global Security Configuration
# Available to all nodes for security scanning and reporting

# Heimdall2 Security Results Server Configuration
heimdall2_reporting:
  # URL to the Heimdall2 security results viewer (running on docker server)
  # Options: "https://docker:8443", "https://heimdall2:8443", or "https://192.168.0.20:8443"
  url: "http://docker:8080"
  
  # API key for uploading scan results
  # Generate this from Heimdall2 web interface: User Settings -> API Keys
  api_key: ""
  
  # Optional: Alternative URL for external access
  # external_url: "https://heimdall.yourdomain.com"

# Security Scanning Configuration
security_scanning:
  # Enable/disable automatic upload to Heimdall2
  auto_upload: true
  
  # Scan frequency (used by systemd timer)
  frequency: "daily"
  
  # Keep scan results for N days
  retention_days: 30
  
  # Additional scan tags
  default_tags:
    - "automated-scan"
    - "homelab"
    - "compliance"

# Security Tool Configuration
security_tools:
  # InSpec profiles to run
  inspec_profiles:
    - "cis-ubuntu"
    - "linux-baseline" 
    - "ssh-baseline"
  
  # Enable/disable specific security tools
  enable_lynis: true
  enable_rkhunter: true
  enable_owasp_zap: true
  enable_nmap_scans: false  # Set to true to enable network scanning
  
  # OWASP ZAP configuration
  zap:
    # Scan localhost web services automatically
    scan_localhost: true
    # Additional targets to scan (optional)
    additional_targets: []
    # ZAP scan type: baseline, full, api
    scan_type: "baseline"

# Example configuration for different environments:
# 
# Development environment might disable auto-upload:
# security_scanning:
#   auto_upload: false
#
# Production environment might have different Heimdall2 server:
# heimdall2_reporting:
#   url: "https://security-dashboard.prod.local"
#   api_key: "prod-api-key-here"