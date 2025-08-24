# Heimdall2 Database Configuration
postgres_databases:
  - name: heimdall2
    users:
      - name: heimdall2_user
        password: H31md@ll2P@ss

# Heimdall2 Application Configuration
heimdall2:
  database_password: H31md@ll2P@ss
  database_host: postgres
  database_name: heimdall2
  database_user: heimdall2_user
  nginx_host: localhost
  jwt_secret: h31md@ll2_jwt_s3cr3t_k3y_ch@ng3_th1s_1n_pr0d
  
  # LDAP Configuration (optional)
  ldap_enabled: false
  # ldap_host: ldap.example.com
  # ldap_port: 389
  # ldap_binddn: cn=admin,dc=example,dc=com
  # ldap_password: ldap_password
  # ldap_searchbase: ou=users,dc=example,dc=com
  # ldap_searchfilter: "(uid={username})"