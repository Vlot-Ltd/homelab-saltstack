include:
  - application.docker
  - application.tailscale-docker

heimdall2_directory:
  file.directory:
    - name: /docker/heimdall2
    - user: root
    - group: docker
    - mode: '0755'
    - makedirs: True
    - require:
      - sls: application.docker

heimdall2_data_directory:
  file.directory:
    - name: /docker/heimdall2/data
    - user: 999
    - group: 999
    - mode: '0755'
    - makedirs: True
    - require:
      - file: heimdall2_directory

heimdall2_nginx_directory:
  file.directory:
    - name: /docker/heimdall2/nginx/conf
    - user: root
    - group: docker
    - mode: '0755'
    - makedirs: True
    - require:
      - file: heimdall2_directory

# Removed certs directory - not needed for basic setup

heimdall2_env:
  file.managed:
    - name: /docker/heimdall2/.env
    - source: salt://application/heimdall2/files/.env.jinja
    - template: jinja
    - user: root
    - group: docker
    - mode: '0640'  # secrets: DB password, JWT/API key secrets (PEP-HL-SLT-030)
    - require:
      - file: heimdall2_directory

heimdall2_nginx_config:
  file.managed:
    - name: /docker/heimdall2/nginx/conf/default.conf.template
    - source: salt://application/heimdall2/files/nginx.conf.jinja
    - template: jinja
    - user: root
    - group: docker
    - mode: '0644'
    - require:
      - file: heimdall2_nginx_directory

heimdall2_compose:
  file.managed:
    - name: /docker/heimdall2/docker-compose.yml
    - source: salt://application/heimdall2/files/docker-compose.yml.jinja
    - template: jinja
    - user: root
    - group: docker
    - mode: '0644'
    - require:
      - file: heimdall2_directory

# PEP-HL-SLT-020 / PEP-HL-SLT-006: no status probe, no pull. Compose or .env
# changes recreate in place; the nginx template is read at container start, so
# a template change restarts only nginx.
heimdall2_start:
  cmd.run:
    - name: docker compose up -d
    - cwd: /docker/heimdall2
    - unless: 'test "$(docker compose ps -q --status running | wc -l)" -ge "$(docker compose config --services | wc -l)"'
    - require:
      - file: heimdall2_compose
      - file: heimdall2_env
      - file: heimdall2_nginx_config
      - cmd: start-tailscale-docker

heimdall2_recreate:
  cmd.run:
    - name: docker compose up -d
    - cwd: /docker/heimdall2
    - onchanges:
      - file: heimdall2_compose
      - file: heimdall2_env
    - require:
      - cmd: heimdall2_start

heimdall2_restart_nginx:
  cmd.run:
    - name: docker compose restart nginx
    - cwd: /docker/heimdall2
    - onchanges:
      - file: heimdall2_nginx_config
    - require:
      - cmd: heimdall2_recreate
