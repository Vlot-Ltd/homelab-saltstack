include:
  - application.docker
  - application.tailscale-docker

webdriver-directory:
  file.directory:
    - name: /docker/webdriver
    - user: root
    - group: docker
    - mode: "0755"

webdriver-docker-compose:
  file.managed:
    - name: /docker/webdriver/docker-compose.yml
    - mode: "0644"
    - contents: |
        networks:
          tailnet:
            external: true
            name: tailnet

        services:
          webdriver:
            container_name: webdriver
            image: selenium/standalone-chrome:latest
            restart: always
            ports:
              - "4444:4444"
              - "7900:7900"
            networks:
              - tailnet
            shm_size: '2gb'
    - require:
        - file: webdriver-directory

# PEP-HL-SLT-020 / PEP-HL-SLT-006: start only when not all services are
# running; recreate in place on compose/env changes. No down, no pull.
start-webdriver:
  cmd.run:
    - name: docker compose up -d
    - cwd: /docker/webdriver
    - unless: 'test "$(docker compose ps -q --status running | wc -l)" -ge "$(docker compose config --services | wc -l)"'
    - require:
        - file: webdriver-docker-compose
        - cmd: start-tailscale-docker

recreate-webdriver:
  cmd.run:
    - name: docker compose up -d
    - cwd: /docker/webdriver
    - onchanges:
        - file: webdriver-docker-compose
    - require:
        - cmd: start-webdriver
