include:
  - database.postgres
  - .repo

zabbix-sql-scripts:
  pkg.installed:
    - require:
      - pkg: install_zabbix-release

zabbix-schema-load:
  cmd.run:
    - name: zcat /tmp/zabbix_schema.sql.gz | sudo -u postgres psql --dbname=zabbix
    - unless: sudo -u postgres psql -tAc "SELECT 1 FROM pg_tables WHERE tablename = 'zabbix_config';"
    - require:
      - pkg: zabbix-sql-scripts
      - cmd: postgres-db-ownership-zabbix
