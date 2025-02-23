include:
  - postgres.database
  - postgres.backup

postgres:
  pkg.installed:
    - name: postgresql

  file.directory:
    - name: /etc/postgresql/14/main/
    - makedirs: True
    - require:
      - pkg: postgresql

  service.running:
    - name: postgresql
    - enable: True
    - require:
      - pkg: postgresql
      - file: /etc/postgresql/14/main/

  file.managed:
    - name: /etc/postgresql/14/main/pg_hba.conf
    - source: salt://postgres/pg_hba.conf.jinja
    - user: postgres
    - group: postgres
    - mode: '0640'
    - template: jinja
    - require:
      - pkg: postgresql
      - file: /etc/postgresql/14/main/

  cmd.run:
    - name: systemctl restart postgresql
    - onchanges:
      - file: /etc/postgresql/14/main/pg_hba.conf