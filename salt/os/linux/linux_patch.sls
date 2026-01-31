apt-get update and upgrade:
  pkg.uptodate:
    - refresh: True

install-latest-kernel:
  kernelpkg.latest_installed: []

report_to_patchmon:
  cmd.run:
    - name: /usr/local/bin//patchmon-agent report
    - onchanges :
      - kernelpkg: install-latest-kernel
      - pkg: apt-get update and upgrade

boot-latest-kernel:
  kernelpkg.latest_active:
    - at_time: 1
    - onchanges:
      - kernelpkg: install-latest-kernel