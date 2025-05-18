include:
  - application.docker

{% set postgres_host = salt['pillar.get']('hosts_entries', []) | selectattr('name', 'equalto', 'postgres') | list | first %}
{% set postgres_ip = postgres_host['ip'] if postgres_host and 'ip' in postgres_host else 'postgres' %}

{% set db_info = salt['pillar.get']('postgres_databases', []) | selectattr('name', 'equalto', 'netbox') | list | first %}
{% set db_user = db_info['users'][0]['name'] if db_info and 'users' in db_info else 'netbox_user' %}
{% set db_password = db_info['users'][0]['password'] if db_info and 'users' in db_info else 'netbox_securepassword' %}

{% set netbox_secret = salt['pillar.get']('netbox_secret', 'banananananas') %}
{% set redis_cache_password = salt['pillar.get']('redis_cache_password', 'banananananas') %}
{% set redis_password = salt['pillar.get']('redis_password', 'babababababa') %}

netbox-directory:
  file.directory:
    - name: /docker/netbox
    - user: root
    - group: docker
    - mode: "0755"

netbox-env-directory:
  file.directory:
    - name: /docker/netbox/env
    - user: root
    - group: docker
    - mode: "0755"

netbox-env-file:
  file.managed:
    - name: /docker/netbox/env/netbox.env
    - contents: |
        CORS_ORIGIN_ALLOW_ALL=True
        DB_HOST={{ postgres_ip }}
        DB_NAME=netbox
        DB_PASSWORD={{ db_password }}
        DB_USER={{ db_user }}
        EMAIL_FROM=netbox@vlot.scot
        EMAIL_PASSWORD=
        EMAIL_PORT=25
        EMAIL_SERVER=localhost
        EMAIL_SSL_CERTFILE=
        EMAIL_SSL_KEYFILE=
        EMAIL_TIMEOUT=5
        EMAIL_USERNAME=netbox
        EMAIL_USE_SSL=false
        EMAIL_USE_TLS=false
        GRAPHQL_ENABLED=true
        HOUSEKEEPING_INTERVAL=86400
        MEDIA_ROOT=/opt/netbox/netbox/media
        METRICS_ENABLED=false
        REDIS_CACHE_DATABASE=1
        REDIS_CACHE_HOST=redis-cache
        REDIS_CACHE_INSECURE_SKIP_TLS_VERIFY=false
        REDIS_CACHE_PASSWORD={{ redis_cache_password }}
        REDIS_CACHE_SSL=false
        REDIS_DATABASE=0
        REDIS_HOST=redis
        REDIS_INSECURE_SKIP_TLS_VERIFY=false
        REDIS_PASSWORD={{ redis_password }}
        REDIS_SSL=false
        RELEASE_CHECK_URL=https://api.github.com/repos/netbox-community/netbox/releases
        SECRET_KEY={{ netbox_secret }}
        SKIP_SUPERUSER=true
        WEBHOOKS_ENABLED=true
    - user: root
    - group: docker
    - mode: "0644"
    - require:
        - file: netbox-env-directory

redis-env-file:
  file.managed:
    - name: /docker/netbox/env/redis.env
    - contents: |
        REDIS_PASSWORD={{ redis_password }}
    - user: root
    - group: docker
    - mode: "0644"
    - require:
        - file: netbox-env-directory

redis-cache-env-file:
  file.managed:
    - name: /docker/netbox/env/redis-cache.env
    - contents: |
        REDIS_CACHE_PASSWORD={{ redis_cache_password }}
    - user: root
    - group: docker
    - mode: "0644"
    - require:
        - file: netbox-env-directory

netbox-docker-compose:
  file.managed:
    - name: /docker/netbox/docker-compose.yml
    - source: salt://netbox/netbox-docker-compose.jinja
    - template: jinja
    - user: root
    - group: docker
    - mode: "0644"
    - require:
        - file: netbox-directory

check-netbox:
  cmd.run:
    - name: docker ps -f status=running | grep -q netbox && echo RUNNING || echo STOPPED
    - output_loglevel: quiet

restart-netbox:
  cmd.run:
    - name: docker compose down && docker pull netboxcommunity/netbox:latest && docker compose up -d
    - cwd: /docker/netbox
    - onlyif: "grep -q RUNNING /var/cache/salt/minion/check-netbox"
    - onchanges:
        - file: netbox-docker-compose
    - require:
        - cmd: check-netbox

start-netbox:
  cmd.run:
    - name: docker compose up -d
    - cwd: /docker/netbox
    - onlyif: "grep -q STOPPED /var/cache/salt/minion/check-netbox"
    - require:
        - cmd: check-netbox
