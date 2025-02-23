{% if salt['pkg.version']('postgresql') %}
{% set pg_version = salt['cmd.shell']("pg_lsclusters --no-header | awk '{print $1}' | sort -nr | head -n1") %}
{% else %}
{% set pg_version = '16' %}
{% endif %}

include:
  - .database
  - .backup

postgres_package:
  pkg.installed:
    - name: postgresql

postgres_hba_config:
  file.managed:
    - name: /etc/postgresql/{{ pg_version }}/main/pg_hba.conf
    - source: salt://database/postgres/files/pg_hba.conf.jinja
    - user: postgres
    - group: postgres
    - mode: '0640'
    - template: jinja
    - require:
      - pkg: postgresql

postgres-config-listen:
  file.replace:
    - name: /etc/postgresql/{{ pg_version }}/main/postgresql.conf
    - pattern: '^listen_addresses\s*=\s*.*$'
    - repl: "listen_addresses = '*'"
    - append_if_not_found: True
    - require:
        - pkg: postgresql


postgres_service:
  service.running:
    - name: postgresql
    - enable: True
    - require:
      - pkg: postgresql
    - watch:
      - file: /etc/postgresql/{{ pg_version }}/main/pg_hba.conf
      - file: postgres-config-listen