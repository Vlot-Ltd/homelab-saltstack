{#- Zabbix release package for this OS. Ubuntu uses e.g. ubuntu24.04, Debian
    uses the major release only, e.g. debian13 (PEP-HL-SLT-031). Skipped once
    a release package of this major version is installed. #}
{%- set zbx = salt['pillar.get']('zabbix:version', '8.0') %}
{%- set distro = grains['os'] | lower %}
{%- set rel = grains['osrelease'] if distro == 'ubuntu' else grains['osmajorrelease'] | string %}

install-zabbix-release:
  pkg.installed:
    - sources:
      - zabbix-release: https://repo.zabbix.com/zabbix/{{ zbx }}/release/{{ distro }}/pool/main/z/zabbix-release/zabbix-release_latest_{{ zbx }}+{{ distro }}{{ rel }}_all.deb
    - unless: dpkg-query -W -f='${Version}' zabbix-release 2>/dev/null | grep -q ':{{ zbx }}-'

{#- Repo files left behind by older release packages. Removed only when no
    installed package owns them. #}
{%- for f in ['zabbix.sources', 'zabbix.list', 'zabbix.list.dpkg-bak', 'zabbix-unstable.list.dpkg-bak'] %}

zabbix-legacy-repo-{{ f }}:
  file.absent:
    - name: /etc/apt/sources.list.d/{{ f }}
    - unless: dpkg -S /etc/apt/sources.list.d/{{ f }}
    - require:
      - pkg: install-zabbix-release
{%- endfor %}
