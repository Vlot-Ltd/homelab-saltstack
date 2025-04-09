include:
  - database.postgres
  - .repo

zabbix-sql-scripts:
  pkg.installed:
    - require:
      - pkg: install-zabbix-release

zabbix-schema-load:
  cmd.run:
    - name: zcat /usr/share/zabbix/sql-scripts/postgresql/server.sql.gz | sudo -u postgres psql --dbname=zabbix
    - unless: sudo -u postgres psql -tAc "SELECT 1 FROM pg_tables WHERE tablename = 'zabbix_config';"
    - require:
      - pkg: zabbix-sql-scripts
      - cmd: postgres-db-ownership-zabbix
