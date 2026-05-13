postgres_databases:
  - name: netbox
    users:
      - name: netbox_user
        password: "{{ salt['vault.read_secret']('salt/roles/db', 'netbox_password') }}"

netbox_secret: "{{ salt['vault.read_secret']('salt/minions/netbox', 'netbox_secret') }}"
redis_cache_password: "{{ salt['vault.read_secret']('salt/minions/netbox', 'redis_cache_password') }}"
redis_password: "{{ salt['vault.read_secret']('salt/minions/netbox', 'redis_password') }}"
superuser_password: "{{ salt['vault.read_secret']('salt/minions/netbox', 'superuser_password') }}"
superuser_email: "{{ salt['vault.read_secret']('salt/minions/netbox', 'superuser_email') }}"
