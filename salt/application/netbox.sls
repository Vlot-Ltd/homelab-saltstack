include:
  - application.docker

{% set postgres_host = salt['pillar.get']('hosts_entries', []) | selectattr('name', 'equalto', 'postgres') | list | first %}
{% set postgres_ip = postgres_host['ip'] if postgres_host and 'ip' in postgres_host else 'postgres' %}

{% set db_info = salt['pillar.get']('postgres_databases', []) | selectattr('name', 'equalto', 'netbox') | list | first %}
{% set db_user = db_info['users'][0]['name'] if db_info and 'users' in db_info else 'netbox_user' %}
{% set db_password = db_info['users'][0]['password'] if db_info and 'users' in db_info else 'netbox_securepassword' %}

netbox-directory:
  file.directory:
    - name: /docker/netbox
    - user: root
    - group: docker
    - mode: "0755"

netbox-env:
  file.managed:
    - name: /docker/netbox/.env
    - mode: "0640"
    - contents: |
        POSTGRES_DB=netbox
        POSTGRES_HOST={{ postgres_ip }}
        POSTGRES_PORT=5432
        POSTGRES_USER={{ db_user }}
        POSTGRES_PASSWORD={{ db_password }}
    - require:
        - file: netbox-directory

netbox-docker-compose:
  file.managed:
    - name: /docker/netbox/docker-compose.yml
    - mode: "0644"
    - contents: |
        services:
          netbox:
            image: netboxcommunity/netbox:latest
            restart: always
            env_file: .env
            ports:
              - "3300:8080"
            depends_on:
              - postgres
    - require:
        - file: netbox-directory

start-netbox:
  cmd.run:
    - name: docker compose up -d
    - cwd: /docker/netbox
    - require:
        - file: netbox-docker-compose
