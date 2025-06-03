redis-server:
  pkg.installed

netbox-prereqs:
  pkg.installed:
    - pkgs:
      - python3
      - python3-pip
      - python3-venv
      - python3-dev
      - build-essential
      - libxml2-dev
      - libxslt1-dev
      - libffi-dev
      - libpq-dev
      - libssl-dev
      - zlib1g-dev

netbox-user:
  user.present:
    - name: netbox
    - usergroup: True
    - system: True

    