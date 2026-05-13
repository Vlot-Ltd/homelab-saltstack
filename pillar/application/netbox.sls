postgres_databases:
  - name: netbox
    users:
      - name: netbox_user
        password: "{{ pillar.get('netbox_password') }}"

netbox_secret: "{{ pillar.get('netbox_secret') }}"
redis_cache_password: "{{ pillar.get('redis_cache_password') }}"
redis_password: "{{ pillar.get('redis_password') }}"
superuser_password: "{{ pillar.get('superuser_password') }}"
superuser_email: "{{ pillar.get('superuser_email') }}"
