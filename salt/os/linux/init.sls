install_required_packages:
  pkg.installed:
    - pkgs:
      - ca-certificates
      - curl
      - dnsutils
      - iputils-ping
      - gnupg
      - git
      - htop
      - lshw
      - lsof
      - net-tools
      - tree
      - wget
      - zsh

/etc/apt/keyrings:
  file.directory:
    - user: root
    - group: root
    - dir_mode: "0755"
    - file_mode: "0644"
    - recurse:
        - user
        - group
        - mode

include:
  - .vim
