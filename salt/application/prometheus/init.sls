# PEP-HL-SLT-028: Prometheus metrics store on the docker host.
#
# TSDB lives in the named volume prometheus-data, not under /docker:
# application.docker resets /docker recursively to root:docker 0644 on every
# highstate, and Prometheus runs as nobody and needs to write.
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
    - name: /docker/prometheus/prometheus.yml
    - source: salt://application/prometheus/files/prometheus.yml.jinja
    - template: jinja
    - user: root
    - group: docker
    - mode: "0644"
    - tmp_dir: /docker/prometheus/.check
    - check_cmd: >-
        docker run --rm --entrypoint promtool
        -v /docker/prometheus/.check:/docker/prometheus/.check:ro
        {{ image }} check config
    - require:
      - file: prometheus-check-directory
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
              - --config.file=/etc/prometheus/prometheus.yml
              - --storage.tsdb.path=/prometheus
              - --storage.tsdb.retention.time={{ prom.get('retention', '400d') }}
              - --web.enable-remote-write-receiver
              - --web.enable-lifecycle
            ports:
              - "{{ port }}:9090"
            volumes:
              - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
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
