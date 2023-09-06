base: 
  'kernel:Linux':
    - match: grain
    - base_linux
    - install_vim
    - linux_patch
  'os:MacOS':
    - match: grain
    - brew_update
  'virtual:kvm':
    - match: grain
    - install_qemu_agent
  'docker*':
    - install_docker
