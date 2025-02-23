{% for db in salt['pillar.get']('postgres_databases', []) %}
postgres-db-{{ db.name }}:
  cmd.run:
    - name: >
        sudo -u postgres psql --dbname=postgres --command='CREATE DATABASE {{ db.name }};'
    - unless: >
        sudo -u postgres psql --dbname=postgres --tuples-only
        --command="SELECT datname FROM pg_database WHERE datname='{{ db.name }}';"
    - require:
      - service: postgresql

{% for user in db.users %}
postgres-user-{{ user.name }}:
  cmd.run:
    - name: >
        sudo -u postgres psql --dbname=postgres --command='
        CREATE USER {{ user.name }} WITH LOGIN ENCRYPTED PASSWORD ''{{ user.password }}'';'
    - unless: >
        sudo -u postgres psql --dbname=postgres --tuples-only
        --command="SELECT rolname FROM pg_roles WHERE rolname='{{ user.name }}';"
    - require:
      - service: postgresql
      - cmd: postgres-db-{{ db.name }}

postgres-privileges-{{ db.name }}-{{ user.name }}:
  cmd.run:
    - name: >
        sudo -u postgres psql --dbname=postgres --command='
        GRANT ALL PRIVILEGES ON DATABASE {{ db.name }} TO {{ user.name }};'
    - unless: >
        sudo -u postgres psql --dbname=postgres --tuples-only
        --command="SELECT 1 FROM information_schema.role_table_grants
        WHERE grantee='{{ user.name }}' AND table_catalog='{{ db.name }}';"
    - require:
      - cmd: postgres-db-{{ db.name }}
      - cmd: postgres-user-{{ user.name }}
{% endfor %}
{% endfor %}