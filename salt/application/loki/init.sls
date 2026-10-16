# PEP-HL-SLT-015 Phase 1: Loki and the central Alloy on the docker host.
#
# One compose project (/docker/loki), so Alloy reaches Loki as loki:3100.
# Alloy reaches Prometheus (its own project) through host.docker.internal.
# Same rules as application.prometheus:
#   - config directories mounted, not single files (a file bind mount pins the
#     inode and Salt replaces files)
#   - data in named volumes, not under /docker
#   - pinned images, up -d on compose changes, no down/up, no implicit pulls
#     (PEP-HL-SLT-020)
# files/loki-config.yaml is a Jinja template (template: jinja below).

{%- set loki = salt['pillar.get']('loki', {}) %}
{%- set alloy = salt['pillar.get']('alloy', {}) %}
{%- set loki_image = loki.get('image', 'grafana/loki:3.5.0') %}
{%- set alloy_image = alloy.get('image', 'grafana/alloy:v1.10.0') %}
{%- set ui_port = alloy.get('ui_port', 12345) %}

include:
  - application.docker

loki-directory:
  file.directory:
    - name: /docker/loki
    - user: root
    - group: docker
    - mode: "0755"

{%- for sub in ['loki', 'alloy', 'check'] %}
loki-directory-{{ sub }}:
  file.directory:
    - name: /docker/loki/{{ '.check' if sub == 'check' else sub }}
    - user: root
    - group: docker
    - mode: "0755"
    - require:
      - file: loki-directory
{%- endfor %}

loki-config:
  file.managed:
    - name: /docker/loki/loki/loki-config.yaml
    - source: salt://application/loki/files/loki-config.yaml
    - template: jinja
    - user: root
    - group: docker
    - mode: "0644"
    - tmp_dir: /docker/loki/.check
    - check_cmd: >-
        docker run --rm --entrypoint /usr/bin/loki
        -v /docker/loki/.check:/docker/loki/.check:ro
        {{ loki_image }} -verify-config -config.file
    - require:
      - file: loki-directory-loki
      - file: loki-directory-check
      - service: docker-service

alloy-config:
  file.managed:
    - name: /docker/loki/alloy/config.alloy
    - source: salt://application/loki/files/config.alloy.jinja
    - template: jinja
    - user: root
    - group: docker
    - mode: "0644"
    - tmp_dir: /docker/loki/.check
    # alloy fmt parses the file and exits non-zero on a syntax error.
    - check_cmd: >-
        docker run --rm --entrypoint /bin/alloy
        -v /docker/loki/.check:/docker/loki/.check:ro
        {{ alloy_image }} fmt
    - require:
      - file: loki-directory-alloy
      - file: loki-directory-check
      - service: docker-service

loki-docker-compose:
  file.managed:
    - name: /docker/loki/docker-compose.yml
    - contents: |
        services:
          loki:
            image: {{ loki_image }}
            container_name: loki
            restart: unless-stopped
            command:
              - -config.file=/etc/loki/config/loki-config.yaml
            ports:
              - "{{ loki.get('port', 3110) }}:3100"
            volumes:
              - ./loki:/etc/loki/config:ro
              - loki-data:/loki

          alloy:
            image: {{ alloy_image }}
            container_name: alloy
            restart: unless-stopped
            command:
              - run
              - --server.http.listen-addr=0.0.0.0:12345
              - --storage.path=/var/lib/alloy/data
              - /etc/alloy/config/config.alloy
            ports:
              - "{{ alloy.get('otlp_grpc_port', 4317) }}:4317"
              - "{{ alloy.get('otlp_http_port', 4318) }}:4318"
              - "{{ ui_port }}:12345"
            extra_hosts:
              - "host.docker.internal:host-gateway"
            volumes:
              - ./alloy:/etc/alloy/config:ro
              - alloy-data:/var/lib/alloy/data
            depends_on:
              - loki

        volumes:
          loki-data:
          alloy-data:
    - user: root
    - group: docker
    - mode: "0644"
    - require:
      - file: loki-directory

start-loki-stack:
  cmd.run:
    - name: docker compose up -d
    - cwd: /docker/loki
    - unless: >-
        test "$(docker ps -q --filter name=^loki$ --filter status=running | wc -l)" -eq 1 &&
        test "$(docker ps -q --filter name=^alloy$ --filter status=running | wc -l)" -eq 1
    - require:
      - file: loki-config
      - file: alloy-config
      - file: loki-docker-compose

recreate-loki-stack-on-compose-change:
  cmd.run:
    - name: docker compose up -d
    - cwd: /docker/loki
    - onchanges:
      - file: loki-docker-compose
    - require:
      - cmd: start-loki-stack

# Loki has no config reload endpoint; restart just that container.
restart-loki-on-config-change:
  cmd.run:
    - name: docker compose restart loki
    - cwd: /docker/loki
    - onchanges:
      - file: loki-config
    - require:
      - cmd: start-loki-stack

reload-alloy-on-config-change:
  cmd.run:
    - name: curl -fsS -X POST http://127.0.0.1:{{ ui_port }}/-/reload
    - retry:
        attempts: 5
        interval: 3
    - onchanges:
      - file: alloy-config
    - require:
      - cmd: start-loki-stack
