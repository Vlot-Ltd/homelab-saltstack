include:
  - application.docker

homepage-directory:
  file.directory:
    - name: /docker/homepage
    - user: root
    - group: docker
    - mode: "0755"

homepage-docker-compose:
  file.managed:
    - name: /docker/homepage/docker-compose.yml
    - contents: |
        version: '3.8'
        services:
          homepage:
            image: ghcr.io/gethomepage/homepage:latest
            restart: unless-stopped
            ports:
              - "0.0.0.0:3000:3000"
            volumes:
              - ./config:/app/config
              - ./images:/app/public/images
            environment:
              - HOMEPAGE_ALLOWED_HOSTS=*  # Allow access from any host
              - PUID=1000
              - PGID=1000
    - user: root
    - group: docker
    - mode: "0644"

check-homepage:
  cmd.run:
    - name: docker ps -f status=running | grep -q homepage && echo RUNNING || echo STOPPED
    - output_loglevel: quiet

restart-homepage:
  cmd.run:
    - name: docker compose down && docker pull ghcr.io/gethomepage/homepage:latest && docker compose up -d
    - cwd: /docker/homepage
    - onlyif: "grep -q RUNNING /var/cache/salt/minion/check-homepage"
    - onchanges:
        - file: homepage-docker-compose
    - require:
        - cmd: check-homepage

start-homepage:
  cmd.run:
    - name: docker compose up -d
    - cwd: /docker/homepage
    - onlyif: "grep -q STOPPED /var/cache/salt/minion/check-homepage"
    - require:
        - cmd: check-homepage
