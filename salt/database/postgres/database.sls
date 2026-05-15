{% set all_databases = salt['pillar.get']('postgres_databases', [], merge=True) %}
{% set monitoring_users = salt['pillar.get']('postgres_monitoring_users', [], merge=True) %}

{% for db in all_databases %}
  {% if 'users' in db and db['users']|length > 0 %}
    {% set owner = salt['pillar.get'](db['users'][0]['name_key']) %}

    {% for user in db['users'] %}
      {% set actual_name = salt['pillar.get'](user['name_key']) %}
      {% set actual_password = salt['pillar.get'](user['password_key']) %}

postgres-user-{{ user['name_key'] }}:
  cmd.run:
    - name: sudo -u postgres psql --dbname=postgres --command="CREATE USER {{ actual_name }} WITH LOGIN ENCRYPTED PASSWORD '{{ actual_password }}';"
    - unless: sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname = '{{ actual_name }}'" | grep -q 1
    {% endfor %}

postgres-db-{{ db['name'] }}:
  cmd.run:
    - name: sudo -u postgres psql --dbname=postgres --command="CREATE DATABASE {{ db['name'] }};"
    - unless: sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname = '{{ db['name'] }}'" | grep -q 1
    - require:
    {% for user in db['users'] %}
        - cmd: postgres-user-{{ user['name_key'] }}
    {% endfor %}

postgres-db-ownership-{{ db['name'] }}:
  cmd.run:
    - name: sudo -u postgres psql -c "ALTER DATABASE {{ db['name'] }} OWNER TO {{ owner }};"
    - unless: sudo -u postgres psql -tAc "SELECT pg_catalog.pg_get_userbyid(datdba) FROM pg_database WHERE datname='{{ db['name'] }}'" | grep -q {{ owner }}
    - require:
        - cmd: postgres-db-{{ db['name'] }}

    {% for user in db['users'] %}
      {% set actual_name = salt['pillar.get'](user['name_key']) %}
postgres-privileges-{{ db['name'] }}-{{ user['name_key'] }}:
  cmd.run:
    - name: sudo -u postgres psql --dbname=postgres --command="GRANT ALL PRIVILEGES ON DATABASE {{ db['name'] }} TO {{ actual_name }};"
    - unless: sudo -u postgres psql -tAc "SELECT has_database_privilege('{{ actual_name }}', '{{ db['name'] }}', 'CONNECT')" | grep -q t
    - require:
        - cmd: postgres-db-ownership-{{ db['name'] }}
    {% endfor %}

  {% endif %}
{% endfor %}

{% for mon_user in monitoring_users %}
  {% set actual_name = salt['pillar.get'](mon_user['name_key']) %}
  {% set actual_password = salt['pillar.get'](mon_user['password_key']) %}

postgres-monitor-user-{{ mon_user['name_key'] }}:
  cmd.run:
    - name: sudo -u postgres psql --dbname=postgres --command="CREATE USER {{ actual_name }} WITH LOGIN ENCRYPTED PASSWORD '{{ actual_password }}';"
    - unless: sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname = '{{ actual_name }}'" | grep -q 1

postgres-monitor-permissions-{{ mon_user['name_key'] }}:
  cmd.run:
    - name: sudo -u postgres psql --dbname=postgres --command="GRANT pg_monitor TO {{ actual_name }};"
    - unless: |
        sudo -u postgres psql -tAc "
        SELECT 1 FROM pg_roles
        WHERE rolname = '{{ actual_name }}'
        AND pg_has_role('{{ actual_name }}', 'pg_monitor', 'USAGE');" | grep -q 1
    - require:
        - cmd: postgres-monitor-user-{{ mon_user['name_key'] }}
{% endfor %}
