'curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg':
  cmd.run:
    - creates: /etc/apt/keyrings/docker.gpg

docker-repo:
  cmd.run:
    - name: >
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg]
        https://download.docker.com/linux/ubuntu
        $(. /etc/os-release && echo $VERSION_CODENAME) stable" |
        tee /etc/apt/sources.list.d/docker.list > /dev/null
    - creates: /etc/apt/sources.list.d/docker.list

install_docker_packages:
  pkg.installed:
    - pkgs:
      - docker-ce
      - docker-ce-cli
      - containerd.io
      - docker-buildx-plugin
      - docker-compose-plugin

docker-service:
  service.running:
    - name: docker
    - enable: True
    - require:
        - pkg: install_docker_packages

docker-group:
  group.present:
    - name: docker
    - addusers:
        - root
        - proxmox

# /docker itself only. No recurse (PEP-HL-SLT-030): each app state owns the
# permissions of its own subtree. A recursive reset made secret .env files
# world-readable and fought app states (and containers) over ownership.
/docker:
  file.directory:
    - user: root
    - group: docker
    - mode: "0755"

# /srv/salt/docker-cleanup.sls

docker-cleanup-cron:
  cron.present:
    - name: /usr/bin/docker system prune -af
    - user: root
    - minute: 0
    - hour: 2
    - require:
      - pkg: install_docker_packages
