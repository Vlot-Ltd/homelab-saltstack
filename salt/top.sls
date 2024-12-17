base:
  '*':
    - common
  'kernel:Linux':
    - match: grain
    - linux.base_linux
    - linux.install_vim
  'os:MacOS':
    - match: grain
    - mac.brew_update
  'virtual:kvm':
    - match: grain
    - linux.install_qemu_agent
  'docker':
    - docker.install_docker
