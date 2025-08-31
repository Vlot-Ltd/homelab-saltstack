include:
  - application.docker

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

# Create Steam tracker service directory and files
steam-tracker-directory:
  file.directory:
    - name: /docker/homepage/steam-tracker
    - user: root
    - group: docker
    - mode: "0755"
    - require:
      - file: homepage-directory

steam-tracker-app:
  file.managed:
    - name: /docker/homepage/steam-tracker/app.py
    - source: salt://application/homepage/files/steam_tracker_app.py
    - user: root
    - group: docker
    - mode: "0644"
    - require:
      - file: steam-tracker-directory

steam-tracker-requirements:
  file.managed:
    - name: /docker/homepage/steam-tracker/requirements.txt
    - source: salt://application/homepage/files/steam_tracker_requirements.txt
    - user: root
    - group: docker
    - mode: "0644"
    - require:
      - file: steam-tracker-directory

steam-tracker-dockerfile:
  file.managed:
    - name: /docker/homepage/steam-tracker/Dockerfile
    - source: salt://application/homepage/files/steam_tracker_dockerfile
    - user: root
    - group: docker
    - mode: "0644"
    - require:
      - file: steam-tracker-directory

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
              - HOMEPAGE_ALLOWED_HOSTS=*
              - PUID=1000
              - PGID=1000
            depends_on:
              - steam-tracker
          
          steam-tracker:
            build: ./steam-tracker
            container_name: steam-tracker
            environment:
              - STEAM_API_KEY={{ salt['vault.read_secret']('secret/data/homepage', 'steam_api_key') if salt['vault.read_secret']('secret/data/homepage', 'steam_api_key') else '' }}
              - STEAM_USER_ID={{ salt['vault.read_secret']('secret/data/homepage', 'steam_user_id') if salt['vault.read_secret']('secret/data/homepage', 'steam_user_id') else '' }}
            ports:
              - "5000:5000"
            restart: unless-stopped
            healthcheck:
              test: ["CMD", "curl", "-f", "http://localhost:5000/health"]
              interval: 30s
              timeout: 10s
              retries: 3
              start_period: 60s
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
        - file: steam-tracker-app
        - file: steam-tracker-requirements
        - file: steam-tracker-dockerfile

start-homepage:
  cmd.run:
    - name: docker compose up -d --build
    - cwd: /docker/homepage
    - onlyif: "grep -q STOPPED /var/cache/salt/minion/check-homepage"
    - require:
        - cmd: check-homepage