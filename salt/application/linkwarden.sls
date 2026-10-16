include:
  - application.docker
  - application.tailscale-docker

{% set postgres_host = salt['pillar.get']('hosts_entries', []) | selectattr('name', 'equalto', 'postgres') | list | first %}
{% set postgres_ip = postgres_host['ip'] if postgres_host and 'ip' in postgres_host else 'postgres' %}

{% set db_info = salt['pillar.get']('postgres_databases', []) | selectattr('name', 'equalto', 'linkwarden') | list | first %}
{% set db_user = salt['pillar.get'](db_info['users'][0]['name_key']) if db_info else '' %}
{% set db_password = salt['pillar.get'](db_info['users'][0]['password_key']) if db_info else '' %}
{% set nextauth_secret = salt['pillar.get']('linkwarden_nextauth_secret', '') %}

linkwarden-directory:
  file.directory:
    - name: /docker/linkwarden
    - user: root
    - group: docker
    - mode: "0755"

linkwarden-env:
  file.managed:
    - name: /docker/linkwarden/.env
    - contents: |
        POSTGRES_USER={{ db_user }}
        POSTGRES_PASSWORD={{ db_password }}
        POSTGRES_DB=linkwarden
        DATABASE_URL=postgresql://{{ db_user }}:{{ db_password }}@{{ postgres_ip }}:5432/linkwarden
        NEXTAUTH_SECRET={{ nextauth_secret }}
    - user: root
    - group: docker
    - mode: "0640"

linkwarden-docker-compose:
  file.managed:
    - name: /docker/linkwarden/docker-compose.yml
    - contents: |
        networks:
          tailnet:
            external: true
            name: tailnet

        services:
          linkwarden:
            env_file: .env
            restart: always
            image: ghcr.io/linkwarden/linkwarden:latest
            container_name: linkwarden
            ports:
              - "3200:3000"
            networks:
              - tailnet
            volumes:
              - ./data:/data/data
    - user: root
    - group: docker
    - mode: "0644"

# PEP-HL-SLT-020 / PEP-HL-SLT-006: start only when not all services are
# running; recreate in place on compose/env changes. No down, no pull.
start-linkwarden:
  cmd.run:
    - name: docker compose up -d
    - cwd: /docker/linkwarden
    - unless: 'test "$(docker compose ps -q --status running | wc -l)" -ge "$(docker compose config --services | wc -l)"'
    - require:
        - file: linkwarden-docker-compose
        - file: linkwarden-env
        - cmd: start-tailscale-docker

recreate-linkwarden:
  cmd.run:
    - name: docker compose up -d
    - cwd: /docker/linkwarden
    - onchanges:
        - file: linkwarden-docker-compose
        - file: linkwarden-env
    - require:
        - cmd: start-linkwarden
