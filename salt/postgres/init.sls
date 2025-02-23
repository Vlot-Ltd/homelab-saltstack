include:
  - postgres.database
  - postgres.backup

postgres_package:
  pkg.installed:
    - name: postgresql

postgres_directory:
  file.directory:
    - name: /etc/postgresql/{{ salt['cmd.run']('pg_lsclusters --no-header | awk '{print $1}' | sort -nr | head -n1') }}/main/
    - makedirs: True
    - require:
      - pkg: postgresql

postgres_service:
  service.running:
    - name: postgresql
    - enable: True
    - require:
      - pkg: postgresql
      - file: /etc/postgresql/{{ salt['cmd.run']('pg_lsclusters --no-header | awk '{print $1}' | sort -nr | head -n1') }}/main/

postgres_hba_config:
  file.managed:
    - name: /etc/postgresql/{{ salt['cmd.run']('pg_lsclusters --no-header | awk '{print $1}' | sort -nr | head -n1') }}/main/pg_hba.conf
    - source: salt://postgres/files/pg_hba.conf.jinja
    - user: postgres
    - group: postgres
    - mode: '0640'
    - template: jinja
    - require:
      - file: /etc/postgresql/{{ salt['cmd.run']('pg_lsclusters --no-header | awk '{print $1}' | sort -nr | head -n1') }}/main/
      - service: postgresql

postgres_restart:
  cmd.run:
    - name: systemctl restart postgresql
    - onchanges:
      - file: /etc/postgresql/{{ salt['cmd.run']('pg_lsclusters --no-header | awk '{print $1}' | sort -nr | head -n1') }}/main/pg_hba.conf