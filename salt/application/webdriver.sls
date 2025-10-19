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

start-webdriver:
  cmd.run:
    - name: docker compose up -d
    - cwd: /docker/webdriver
    - require:
        - file: webdriver-docker-compose
        - cmd: start-tailscale-docker
