system-update:
  pkg.uptodate:
    - refresh: True
{% if grains['os_family'] == 'Debian' %}
    - dist_upgrade: True
{% endif %}

autoremove-obsolete:
  cmd.run:
{% if grains['os_family'] == 'Debian' %}
    - name: apt-get autoremove -y
{% elif grains['os_family'] == 'RedHat' %}
    - name: dnf autoremove -y
{% endif %}
    - onchanges:
      - pkg: system-update

report_to_patchmon:
  cmd.run:
    - name: /usr/local/bin/patchmon-agent report
    - onchanges:
      - pkg: system-update

reboot_if_required:
  cmd.run:
    - name: shutdown -r +1 "Rebooting for kernel update"
{% if grains['os_family'] == 'Debian' %}
    - onlyif: test -f /var/run/reboot-required
{% elif grains['os_family'] == 'RedHat' %}
    - onlyif: needs-restarting -r; test $? -eq 1
{% endif %}
    - onchanges:
      - pkg: system-update