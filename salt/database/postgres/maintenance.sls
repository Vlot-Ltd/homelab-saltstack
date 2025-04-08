{% set maintenance = salt['pillar.get']('postgres_maintenance', {}) %}
{% set schedule = maintenance.get('schedule', 'daily') %}

{% if maintenance.get('autovacuum', True) %}
postgres-enable-autovacuum:
  cmd.run:
    - name: sudo -u postgres psql -c "ALTER SYSTEM SET autovacuum = 'on';"
    - unless: sudo -u postgres psql -tAc "SHOW autovacuum;" | grep -q 'on'
    - require:
        - service: postgresql
{% endif %}

postgres-maintenance-script:
  file.managed:
    - name: /usr/local/bin/postgres_maintenance.sh
    - mode: "0755"
    - contents: |
        #!/bin/bash
        sudo -u postgres psql -c "VACUUM FULL;"
        sudo -u postgres psql -c "ANALYZE;"
        sudo -u postgres psql -c "REINDEX DATABASE postgres;"
    - require:
        - service: postgresql

postgres-maintenance-cron:
  cron.present:
    - name: /usr/local/bin/postgres_maintenance.sh > /var/log/postgres_maintenance.log 2>&1
    - user: postgres
    - minute: 0
    - hour: 0
    - require:
        - file: postgres-maintenance-script
