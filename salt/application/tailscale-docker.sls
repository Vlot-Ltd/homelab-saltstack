include:
  - application.docker

tailscale-docker-directory:
  file.directory:
    - name: /docker/tailscale
    - user: root
    - group: docker
    - mode: "0755"

tailscale-docker-compose:
  file.managed:
    - name: /docker/tailscale/docker-compose.yml
    - contents: |
        networks:
          tailnet:
            driver: bridge
            name: tailnet

        services:
          tailscale:
            image: tailscale/tailscale:latest
            container_name: tailscale-sidecar
            hostname: homelab
            environment:
              - TS_AUTHKEY={{ salt['pillar.get']('tailscale_api', '') }}
              - TS_STATE_DIR=/var/lib/tailscale
              - TS_USERSPACE=false
              - TS_EXTRA_ARGS=--advertise-tags=tag:container
            volumes:
              - tailscale-state:/var/lib/tailscale
              - /dev/net/tun:/dev/net/tun
            cap_add:
              - NET_ADMIN
              - SYS_MODULE
            restart: unless-stopped
            networks:
              - tailnet

        volumes:
          tailscale-state:
    - user: root
    - group: docker
    - mode: "0644"

# Running-state checks query docker directly. The old checks grepped
# /var/cache/salt/minion/check-tailscale-docker, which nothing writes, so the
# sidecar was never started (PEP-HL-SLT-006).
restart-tailscale-docker:
  cmd.run:
    - name: docker compose down && docker compose up -d
    - cwd: /docker/tailscale
    - onlyif: docker ps -q --filter name=^tailscale-sidecar$ --filter status=running | grep -q .
    - onchanges:
        - file: tailscale-docker-compose

start-tailscale-docker:
  cmd.run:
    - name: docker compose up -d
    - cwd: /docker/tailscale
    - unless: docker ps -q --filter name=^tailscale-sidecar$ --filter status=running | grep -q .
    - require:
        - file: tailscale-docker-compose
