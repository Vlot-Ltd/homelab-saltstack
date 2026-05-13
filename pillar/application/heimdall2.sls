# Heimdall2 Database Configuration
postgres_databases:
  - name: heimdall2
    users:
      - name: heimdall2_user
        password: "{{ pillar.get('heimdall2_password') }}"

# Heimdall2 Application Configuration
heimdall2:
  database_password: "{{ pillar.get('heimdall2_password') }}"
  database_host: postgres
  database_name: heimdall2
  database_user: heimdall2_user
  nginx_host: localhost
  jwt_secret: "{{ pillar.get('heimdall2_jwt_secret') }}"
  api_key_secret: "{{ pillar.get('heimdall2_api_secret') }}"

  # LDAP Configuration (optional)
  ldap_enabled: false
  # ldap_host: ldap.example.com
  # ldap_port: 389
  # ldap_binddn: cn=admin,dc=example,dc=com
  # ldap_password: ldap_password
  # ldap_searchbase: ou=users,dc=example,dc=com
  # ldap_searchfilter: "(uid={username})"
