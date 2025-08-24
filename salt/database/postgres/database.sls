{% set all_databases = salt['pillar.get']('postgres_databases', [], merge=True) %}
{% set monitoring_users = salt['pillar.get']('postgres_monitoring_users', [], merge=True) %}

{% for db in all_databases %}
  {% if 'users' in db and db['users']|length > 0 %}
    {% set owner = db['users'][0]['name'] %}
    
    # Create all users for this database first
    {% for user in db['users'] %}
postgres-user-{{ user['name'] }}:
  cmd.run:
    - name: sudo -u postgres psql --dbname=postgres --command="CREATE USER {{ user['name'] }} WITH LOGIN ENCRYPTED PASSWORD '{{ user['password'] }}';"
    - unless: sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname = '{{ user['name'] }}'" | grep -q 1
    {% endfor %}

    # Create the database after all users exist
postgres-db-{{ db['name'] }}:
  cmd.run:
    - name: sudo -u postgres psql --dbname=postgres --command="CREATE DATABASE {{ db['name'] }};"
    - unless: sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname = '{{ db['name'] }}'" | grep -q 1
    - require:
    {% for user in db['users'] %}
        - cmd: postgres-user-{{ user['name'] }}
    {% endfor %}

    # Set database ownership
postgres-db-ownership-{{ db['name'] }}:
  cmd.run:
    - name: sudo -u postgres psql -c "ALTER DATABASE {{ db['name'] }} OWNER TO {{ owner }};"
    - unless: sudo -u postgres psql -tAc "SELECT pg_catalog.pg_get_userbyid(datdba) FROM pg_database WHERE datname='{{ db['name'] }}'" | grep -q {{ owner }}
    - require:
        - cmd: postgres-db-{{ db['name'] }}

    # Grant privileges to all users
    {% for user in db['users'] %}
postgres-privileges-{{ db['name'] }}-{{ user['name'] }}:
  cmd.run:
    - name: sudo -u postgres psql --dbname=postgres --command="GRANT ALL PRIVILEGES ON DATABASE {{ db['name'] }} TO {{ user['name'] }};"
    - unless: sudo -u postgres psql -tAc "SELECT has_database_privilege('{{ user['name'] }}', '{{ db['name'] }}', 'CONNECT')" | grep -q t
    - require:
        - cmd: postgres-db-ownership-{{ db['name'] }}
    {% endfor %}

  {% endif %}
{% endfor %}

{% for mon_user in monitoring_users %}
postgres-monitor-user-{{ mon_user['name'] }}:
  cmd.run:
    - name: sudo -u postgres psql --dbname=postgres --command="CREATE USER {{ mon_user['name'] }} WITH LOGIN ENCRYPTED PASSWORD '{{ mon_user['password'] }}';"
    - unless: sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname = '{{ mon_user['name'] }}';"

postgres-monitor-permissions-{{ mon_user['name'] }}:
  cmd.run:
    - name: sudo -u postgres psql --dbname=postgres --command="GRANT pg_monitor TO {{ mon_user['name'] }};"
    - unless: |
        sudo -u postgres psql -tAc "
        SELECT 1 FROM pg_roles
        WHERE rolname = '{{ mon_user['name'] }}'
        AND pg_has_role('{{ mon_user['name'] }}', 'pg_monitor', 'USAGE');" | grep -q 1
    - require:
        - cmd: postgres-monitor-user-{{ mon_user['name'] }}
{% endfor %}
