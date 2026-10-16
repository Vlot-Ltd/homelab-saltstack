include:
  - application.docker

fing-directory:
  file.directory:
    - name: /docker/fing
    - user: root
    - group: docker
    - mode: "0755"

fing-data-directory:
  file.directory:
    - name: /docker/fing/data
    - user: root
    - group: docker
    - mode: "0755"
    - require:
      - file: fing-directory

fing-docker-compose:
  file.managed:
    - name: /docker/fing/docker-compose.yml
    - contents: |
        services:
          fing-agent:
            image: fing/fing-agent:latest
            container_name: fing-agent
            restart: unless-stopped
            network_mode: host
            cap_add:
              - NET_ADMIN
            ports:
              - "44444:44444"
            volumes:
              - ./data:/opt/fing/data
            environment:
              # Add any environment variables here if needed in future
              - TZ=UTC
    - user: root
    - group: docker
    - mode: "0644"
    - require:
      - file: fing-directory

# PEP-HL-SLT-020 / PEP-HL-SLT-006: start only when not all services are
# running; recreate in place on compose/env changes. No down, no pull.
start-fing:
  cmd.run:
    - name: docker compose up -d
    - cwd: /docker/fing
    - unless: 'test "$(docker compose ps -q --status running | wc -l)" -ge "$(docker compose config --services | wc -l)"'
    - require:
        - file: fing-docker-compose
        - file: fing-data-directory

recreate-fing:
  cmd.run:
    - name: docker compose up -d
    - cwd: /docker/fing
    - onchanges:
        - file: fing-docker-compose
    - require:
        - cmd: start-fing
