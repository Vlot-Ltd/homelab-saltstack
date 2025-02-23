include:
  - postgres.database
  - postgres.backup

postgres_package:
  pkg.installed:
    - name: postgresql

postgres_directory:
  file.directory:
    - name: /etc/postgresql/14/main/
    - makedirs: True
    - require:
      - pkg: postgresql

postgres_service:
  service.running:
    - name: postgresql
    - enable: True
    - require:
      - pkg: postgresql
      - file: /etc/postgresql/14/main/

postgres_hba_config:
  file.managed:
    - name: /etc/postgresql/14/main/pg_hba.conf
    - source: salt://postgres/pg_hba.conf.jinja
    - user: postgres
    - group: postgres
    - mode: '0640'
    - template: jinja
    - require:
      - file: /etc/postgresql/14/main/
      - service: postgresql

postgres_restart:
  cmd.run:
    - name: systemctl restart postgresql
    - onchanges:
      - file: /etc/postgresql/14/main/pg_hba.conf