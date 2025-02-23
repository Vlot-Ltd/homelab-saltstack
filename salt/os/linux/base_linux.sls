install_required_packages:
  pkg.installed:
    - pkgs:
      - ca-certificates
      - curl
      - gnupg
      - vim

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

