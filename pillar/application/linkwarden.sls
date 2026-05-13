postgres_databases:
  - name: linkwarden
    users:
      - name: linkwardenuser
        password: "{{ salt['vault.read_secret']('salt/roles/db', 'linkwarden_password') }}"
