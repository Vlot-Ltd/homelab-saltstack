# Heimdall2 Database Configuration
postgres_databases:
  - name: heimdall2
    users:
      - name_key: heimdall2_db_user
        password_key: heimdall2_db_password

# Heimdall2 Application Configuration
heimdall2:
  database_host: postgres
  database_name: heimdall2
  nginx_host: localhost

  # LDAP Configuration (optional)
  ldap_enabled: false
  # ldap_host: ldap.example.com
  # ldap_port: 389
  # ldap_binddn: cn=admin,dc=example,dc=com
  # ldap_password: ldap_password
  # ldap_searchbase: ou=users,dc=example,dc=com
  # ldap_searchfilter: "(uid={username})"
