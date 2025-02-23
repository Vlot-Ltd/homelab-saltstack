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

/docker:
  file.directory:
    - user: root
    - group: docker
    - dir_mode: "0755"
    - file_mode: "0644"
    - recurse:
        - user
        - group
        - mode
