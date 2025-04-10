include:
  - application.docker

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
        services:
          webdriver:
            container_name: webdriver
            image: selenium/standalone-chrome:latest
            restart: always
            env_file: .env
            ports:
              - "4444:4444"
              - "7900:7900"
            shm_size: '2gb'
    - require:
        - file: webdriver-directory

start-webdriver:
  cmd.run:
    - name: docker compose up -d
    - cwd: /docker/webdriver
    - require:
        - file: webdriver-docker-compose
