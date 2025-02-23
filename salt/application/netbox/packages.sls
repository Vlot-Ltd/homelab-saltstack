netbox_packages:
  pkg.installed:
    - names:
      - python3-pip
      - python3-dev
      - python3-venv
      - libpq-dev
      - postgresql
      - postgresql-contrib
      - nginx
      - redis-server
      - git