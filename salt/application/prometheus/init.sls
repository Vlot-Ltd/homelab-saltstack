# PEP-HL-SLT-028: Prometheus metrics store on the docker host.
#
# TSDB lives in the named volume prometheus-data, not under /docker:
# application.docker resets /docker recursively to root:docker 0644 on every
# highstate, and Prometheus runs as nobody and needs to write.
#
# Config sits in /docker/prometheus/config, mounted as a directory: a single-file
# bind mount pins the inode, and Salt replaces files, so the container would keep
# reading the old config after a reload (hit 2026-10-17).
#
# Config changes reload in place (POST /-/reload, --web.enable-lifecycle);
# compose changes recreate with up -d. No down/up, no implicit pulls
# (PEP-HL-SLT-020).

{%- set prom = salt['pillar.get']('prometheus', {}) %}
{%- set image = prom.get('image', 'prom/prometheus:v3.5.0') %}
{%- set port = prom.get('port', 9090) %}

include:
  - application.docker

prometheus-directory:
  file.directory:
    - name: /docker/prometheus
    - user: root
    - group: docker
    - mode: "0755"

# Scrape credentials live outside /docker (application.docker resets /docker to
# 0644 recursively). Owned by nobody (uid 65534, Prometheus's user in the image).
prometheus-secrets-directory:
  file.directory:
    - name: /etc/prometheus-secrets
    - user: nobody
    - group: root
    - mode: "0500"

{%- if prom.get('homeassistant', {}).get('enabled', False) %}
prometheus-homeassistant-token:
  file.managed:
    - name: /etc/prometheus-secrets/homeassistant_token
    # From Vault salt/minions/docker; fails loudly if the key is missing.
    - contents_pillar: homeassistant_prometheus_token
    - user: nobody
    - group: root
    - mode: "0400"
    - show_changes: False
    - require:
      - file: prometheus-secrets-directory
    - require_in:
      - file: prometheus-config
{%- endif %}

prometheus-config-directory:
  file.directory:
    - name: /docker/prometheus/config
    - user: root
    - group: docker
    - mode: "0755"
    - require:
      - file: prometheus-directory

# Old single-file location, before the directory mount.
prometheus-config-old-location:
  file.absent:
    - name: /docker/prometheus/prometheus.yml
    - require:
      - cmd: recreate-prometheus-on-compose-change

# Scratch dir for check_cmd, so promtool in the container can see the candidate file.
prometheus-check-directory:
  file.directory:
    - name: /docker/prometheus/.check
    - user: root
    - group: docker
    - mode: "0755"
    - require:
      - file: prometheus-directory

prometheus-config:
  file.managed:
    - name: /docker/prometheus/config/prometheus.yml
    - source: salt://application/prometheus/files/prometheus.yml.jinja
    - template: jinja
    - user: root
    - group: docker
    - mode: "0644"
    - tmp_dir: /docker/prometheus/.check
    - check_cmd: >-
        docker run --rm --entrypoint promtool
        -v /docker/prometheus/.check:/docker/prometheus/.check:ro
        -v /etc/prometheus-secrets:/etc/prometheus/secrets:ro
        {{ image }} check config
    - require:
      - file: prometheus-check-directory
      - file: prometheus-config-directory
      - file: prometheus-secrets-directory
      - service: docker-service

prometheus-docker-compose:
  file.managed:
    - name: /docker/prometheus/docker-compose.yml
    - contents: |
        services:
          prometheus:
            image: {{ image }}
            container_name: prometheus
            restart: unless-stopped
            command:
              - --config.file=/etc/prometheus/config/prometheus.yml
              - --storage.tsdb.path=/prometheus
              - --storage.tsdb.retention.time={{ prom.get('retention', '400d') }}
              - --web.enable-remote-write-receiver
              - --web.enable-lifecycle
            ports:
              - "{{ port }}:9090"
            volumes:
              - ./config:/etc/prometheus/config:ro
              - /etc/prometheus-secrets:/etc/prometheus/secrets:ro
              - prometheus-data:/prometheus

        volumes:
          prometheus-data:
    - user: root
    - group: docker
    - mode: "0644"
    - require:
      - file: prometheus-directory

start-prometheus:
  cmd.run:
    - name: docker compose up -d
    - cwd: /docker/prometheus
    - unless: docker ps -q --filter name=^prometheus$ --filter status=running | grep -q .
    - require:
      - file: prometheus-config
      - file: prometheus-docker-compose

recreate-prometheus-on-compose-change:
  cmd.run:
    - name: docker compose up -d
    - cwd: /docker/prometheus
    - onchanges:
      - file: prometheus-docker-compose
    - require:
      - cmd: start-prometheus

reload-prometheus-on-config-change:
  cmd.run:
    - name: curl -fsS -X POST http://127.0.0.1:{{ port }}/-/reload
    # First apply: the container may still be starting when this fires.
    - retry:
        attempts: 5
        interval: 3
    - onchanges:
      - file: prometheus-config
    - require:
      - cmd: start-prometheus
