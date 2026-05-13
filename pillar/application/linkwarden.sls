postgres_databases:
  - name: linkwarden
    users:
      - name: linkwardenuser
        password: "{{ pillar.get('linkwarden_password') }}"
