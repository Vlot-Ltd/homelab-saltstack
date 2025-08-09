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
        version: '3.8'
        
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

check-fing:
  cmd.run:
    - name: docker ps -f status=running | grep -q fing-agent && echo RUNNING || echo STOPPED
    - output_loglevel: quiet

restart-fing:
  cmd.run:
    - name: docker compose down && docker pull fing/fing-agent:latest && docker compose up -d
    - cwd: /docker/fing
    - onlyif: "grep -q RUNNING /var/cache/salt/minion/check-fing"
    - onchanges:
        - file: fing-docker-compose
    - require:
        - cmd: check-fing

start-fing:
  cmd.run:
    - name: docker compose up -d
    - cwd: /docker/fing
    - onlyif: "grep -q STOPPED /var/cache/salt/minion/check-fing"
    - require:
        - cmd: check-fing
        - file: fing-data-directory