{% from 'common/map.jinja' import common with context %}

include:
  - application.docker

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

heimdall2_certs_directory:
  file.directory:
    - name: /docker/heimdall2/certs
    - user: root
    - group: docker
    - mode: '0755'
    - makedirs: True
    - require:
      - file: heimdall2_directory

heimdall2_env:
  file.managed:
    - name: /docker/heimdall2/.env
    - source: salt://application/heimdall2/files/.env.jinja
    - template: jinja
    - user: root
    - group: docker
    - mode: '0644'
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

heimdall2_status:
  cmd.run:
    - name: docker ps -f status=running | grep -q heimdall2
    - cwd: /docker/heimdall2
    - success_retcodes: [0, 1]

heimdall2_start:
  cmd.run:
    - name: docker compose up -d
    - cwd: /docker/heimdall2
    - unless: docker ps -f status=running | grep -q heimdall2
    - require:
      - file: heimdall2_compose
      - file: heimdall2_env
      - file: heimdall2_nginx_config
      - cmd: heimdall2_status

heimdall2_restart:
  cmd.run:
    - name: docker compose pull && docker compose up -d
    - cwd: /docker/heimdall2
    - onlyif: docker ps -f status=running | grep -q heimdall2
    - require:
      - file: heimdall2_compose
      - file: heimdall2_env
      - file: heimdall2_nginx_config
    - watch:
      - file: heimdall2_compose
      - file: heimdall2_env
      - file: heimdall2_nginx_config