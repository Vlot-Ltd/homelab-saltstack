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
              - TS_AUTHKEY={{ salt['vault.read_secret']('secret/data/tailscale', 'auth_key') if salt['vault.read_secret']('secret/data/tailscale', 'auth_key') else '' }}
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

check-tailscale-docker:
  cmd.run:
    - name: docker ps -f status=running | grep -q tailscale-sidecar && echo RUNNING || echo STOPPED
    - output_loglevel: quiet

restart-tailscale-docker:
  cmd.run:
    - name: docker compose down && docker compose up -d
    - cwd: /docker/tailscale
    - onlyif: "grep -q RUNNING /var/cache/salt/minion/check-tailscale-docker"
    - onchanges:
        - file: tailscale-docker-compose
    - require:
        - cmd: check-tailscale-docker

start-tailscale-docker:
  cmd.run:
    - name: docker compose up -d
    - cwd: /docker/tailscale
    - onlyif: "grep -q STOPPED /var/cache/salt/minion/check-tailscale-docker"
    - require:
        - cmd: check-tailscale-docker