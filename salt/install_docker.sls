'curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg':
  cmd.run:
    - creates: /etc/apt/keyrings/docker.gpg

'echo "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null':
  cmd.run:
    - creates: /etc/apt/sources.list.d/docker.list

install_docker_packages:
  pkg.installed:
    - pkgs:
      - docker-ce
      - docker-ce-cli
      - containerd.io
      - docker-buildx-plugin
      - docker-compose-plugin

/docker:
  file.directory:
    - user: root
    - group: root
    - dir_mode: 0755
    - file_mode: 0644
    - recurse:
        - user
        - group
        - mode
