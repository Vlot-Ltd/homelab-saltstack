postgresql_db:
  postgres_database.present:
    - name: netbox
    - owner: netbox
    - lc_collate: en_US.utf8
    - lc_ctype: en_US.utf8
    - encoding: UTF8
    - template: template0

postgresql_user:
  postgres_user.present:
    - name: netbox
    - password: 'n3tb0XpW!'
    - createdb: False

postgresql_privileges:
  postgres_privileges.present:
    - name: netbox
    - object_name: netbox
    - object_type: database
    - privileges:
      - ALL