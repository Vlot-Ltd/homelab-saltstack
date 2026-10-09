include:
  - application.docker
  - application.tailscale-docker

homepage-directory:
  file.directory:
    - name: /docker/homepage
    - user: root
    - group: docker
    - mode: "0755"

homepage-config-directory:
  file.directory:
    - name: /docker/homepage/config
    - user: root
    - group: docker
    - mode: "0755"
    - require:
      - file: homepage-directory

# Create template files directory structure
homepage-files-directory:
  file.directory:
    - name: /srv/salt/application/homepage/files
    - makedirs: True
    - user: root
    - group: root
    - mode: "0755"

# steam-tracker: designed but never built (2026-10-09). The source files below
# don't exist, so these states are disabled until the service is written.
# Spec: vault note entertainment-release-tracker. Tracked in homelab-salt-fix.
# # Create Steam tracker service directory and files
# steam-tracker-directory:
#   file.directory:
#     - name: /docker/homepage/steam-tracker
#     - user: root
#     - group: docker
#     - mode: "0755"
#     - require:
#       - file: homepage-directory

# steam-tracker-app:
#   file.managed:
#     - name: /docker/homepage/steam-tracker/app.py
#     - source: salt://application/homepage/files/steam_tracker_app.py
#     - user: root
#     - group: docker
#     - mode: "0644"
#     - require:
#       - file: steam-tracker-directory

# steam-tracker-requirements:
#   file.managed:
#     - name: /docker/homepage/steam-tracker/requirements.txt
#     - source: salt://application/homepage/files/steam_tracker_requirements.txt
#     - user: root
#     - group: docker
#     - mode: "0644"
#     - require:
#       - file: steam-tracker-directory

# steam-tracker-dockerfile:
#   file.managed:
#     - name: /docker/homepage/steam-tracker/Dockerfile
#     - source: salt://application/homepage/files/steam_tracker_dockerfile
#     - user: root
#     - group: docker
#     - mode: "0644"
#     - require:
#       - file: steam-tracker-directory

homepage-services-config:
  file.managed:
    - name: /docker/homepage/config/services.yaml
    - source: salt://application/homepage/files/services.yaml.jinja
    - template: jinja
    - user: root
    - group: docker
    - mode: "0644"
    - require:
        - file: homepage-config-directory

homepage-settings-config:
  file.managed:
    - name: /docker/homepage/config/settings.yaml
    - source: salt://application/homepage/files/settings.yaml.jinja
    - template: jinja
    - user: root
    - group: docker
    - mode: "0644"
    - require:
        - file: homepage-config-directory

homepage-widgets-config:
  file.managed:
    - name: /docker/homepage/config/widgets.yaml
    - source: salt://application/homepage/files/widgets.yaml.jinja
    - template: jinja
    - user: root
    - group: docker
    - mode: "0644"
    - require:
        - file: homepage-config-directory

homepage-docker-compose:
  file.managed:
    - name: /docker/homepage/docker-compose.yml
    - contents: |
        networks:
          tailnet:
            external: true
            name: tailnet

        services:
          homepage:
            image: ghcr.io/gethomepage/homepage:latest
            container_name: homepage
            restart: unless-stopped
            ports:
              - "3000:3000"
            networks:
              - tailnet
            volumes:
              - ./config:/app/config
              - ./images:/app/public/images
            environment:
              - HOMEPAGE_ALLOWED_HOSTS=*
              - PUID=1000
              - PGID=1000
        # steam-tracker service disabled until it's built (see the note above).
        # Restore depends_on: [steam-tracker] on homepage when it is.
    - user: root
    - group: docker
    - mode: "0644"
    - require:
        - file: homepage-directory

check-homepage:
  cmd.run:
    - name: docker ps -f status=running | grep -q homepage && echo RUNNING || echo STOPPED
    - output_loglevel: quiet

restart-homepage-on-config-change:
  cmd.run:
    - name: docker compose down && docker compose up -d --build
    - cwd: /docker/homepage
    - onchanges:
        - file: homepage-services-config
        - file: homepage-settings-config  
        - file: homepage-widgets-config
        - file: homepage-docker-compose

start-homepage:
  cmd.run:
    - name: docker compose up -d --build
    - cwd: /docker/homepage
    - onlyif: "grep -q STOPPED /var/cache/salt/minion/check-homepage"
    - require:
        - cmd: check-homepage
        - cmd: start-tailscale-docker