include:
  - application.docker

{% set db_info = salt['pillar.get']('postgres_databases', []) | selectattr('name', 'equalto', 'linkwarden') | list | first %}
{% if db_info and 'users' in db_info %}
{% set db_user = db_info['users'][0]['name'] %}
{% set db_password = db_info['users'][0]['password'] %}
{% else %}
{% set db_user = 'linkwarden_user' %}
{% set db_password = 'linkwarden_securepassword' %}
{% endif %}

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
        DATABASE_URL=postgresql://{{ db_user }}:{{ db_password }}@postgres:5432/linkwarden
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
              - "3200:3000"
            volumes:
              - ./data:/data/data
    - user: root
    - group: docker
    - mode: "0644"

linkwarden-container:
  cmd.run:
    - name: "docker compose up -d"
    - cwd: /docker/linkwarden
    - require:
        - file: linkwarden-docker-compose
        - file: linkwarden-env
        - service: docker-service