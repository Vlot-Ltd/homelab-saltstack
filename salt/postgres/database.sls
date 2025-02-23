{% set databases = salt['pillar.get']('postgres_databases', []) %}
{% for db in databases %}
postgres-db-{{ db.name }}:
  cmd.run:
    - name: "sudo -u postgres psql -c \"CREATE DATABASE {{ db.name }};\""
    - unless: "sudo -u postgres psql -tAc \"SELECT 1 FROM pg_database WHERE datname='{{ db.name }}';\""
    - require:
      - service: postgresql
      - cmd: postgres_restart


{% for user in db.users %}
postgres-user-{{ user.name }}:
  cmd.run:
    - name: "sudo -u postgres psql -c \"CREATE USER {{ user.name }} WITH ENCRYPTED PASSWORD '{{ user.password }}';\""
    - unless: "sudo -u postgres psql -tAc \"SELECT 1 FROM pg_roles WHERE rolname='{{ user.name }}';\""
    - require:
      - service: postgresql
      - cmd: postgres-db-{{ db.name }}

postgres-privileges-{{ db.name }}-{{ user.name }}:
  cmd.run:
    - name: "sudo -u postgres psql -c \"GRANT ALL PRIVILEGES ON DATABASE {{ db.name }} TO {{ user.name }};\""
    - require:
      - cmd: postgres-db-{{ db.name }}
      - cmd: postgres-user-{{ user.name }}
{% endfor %}
{% endfor %}