netbox_packages:
  pkg.installed:
    - names:
      - python3-pip
      - python3-dev
      - libpq-dev
      - postgresql
      - postgresql-contrib
      - nginx
      - redis-server
      - git