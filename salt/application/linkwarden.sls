include:
  - application.docker

{% set postgres_host = salt['pillar.get']('hosts_entries', []) | selectattr('name', 'equalto', 'postgres') | list | first %}
{% set postgres_ip = postgres_host['ip'] if postgres_host and 'ip' in postgres_host else 'postgres' %}

{% set db_info = salt['pillar.get']('postgres_databases', []) | selectattr('name', 'equalto', 'linkwarden') | list | first %}
{% set db_user = db_info['users'][0]['name'] if db_info and 'users' in db_info else 'linkwarden_user' %}
{% set db_password = db_info['users'][0]['password'] if db_info and 'users' in db_info else 'linkwarden_securepassword' %}

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
    - user: root
    - group: docker
    - mode: "0640"

linkwarden-docker-compose:
  file.managed:
    - name: /docker/linkwarden/docker-compose.yml
    - contents: |
        version: "3.5"
        services:
          linkwarden:
            env_file: .env
            restart: always
            image: ghcr.io/linkwarden/linkwarden:latest
            ports:
              - "3200:3000"  # Corrected port to 3200
            volumes:
              - ./data:/data/data
    - user: root
    - group: docker
    - mode: "0644"

check-linkwarden:
  cmd.run:
    - name: docker ps -f status=running | grep -q linkwarden && echo RUNNING || echo STOPPED
    - output_loglevel: quiet

restart-linkwarden:
  cmd.run:
    - name: docker compose down && docker pull ghcr.io/linkwarden/linkwarden:latest && docker compose up -d
    - cwd: /docker/linkwarden
    - onlyif: "grep -q RUNNING /var/cache/salt/minion/check-linkwarden"
    - onchanges:
        - file: linkwarden-docker-compose
        - file: linkwarden-env
    - require:
        - cmd: check-linkwarden

start-linkwarden:
  cmd.run:
    - name: docker compose up -d
    - cwd: /docker/linkwarden
    - onlyif: "grep -q STOPPED /var/cache/salt/minion/check-linkwarden"
    - require:
        - cmd: check-linkwarden