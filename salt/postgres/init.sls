include:
  - postgres.database
  - postgres.backup

postgres:
  pkg.installed:
    - name: postgresql

  service.running:
    - name: postgresql
    - enable: True
    - require:
      - pkg: postgres

  file.managed:
    - name: /etc/postgresql/14/main/pg_hba.conf
    - source: salt://postgres/files/pg_hba.conf.jinja
    - user: postgres
    - group: postgres
    - mode: '0640'
    - template: jinja
    - require:
      - pkg: postgres

  cmd.run:
    - name: systemctl restart postgresql
    - onchanges:
      - file: /etc/postgresql/14/main/pg_hba.conf