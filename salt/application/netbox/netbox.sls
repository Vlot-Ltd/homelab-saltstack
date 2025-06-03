{% set netbox_version = '4.3.1' %}
{% set netbox_base_url = "https://github.com/netbox-community/netbox/archive/refs/tags/" %}
{% set netbox_download_url = netbox_base_url + "v" + netbox_version + "tar.gz" %}



unpack_netbox:
  archive.extracted:
    - name: /opt
    - source: {{ netbox_download_url }}
    - creates: /opt/netbox-{{ netbox_version }}/

/opt/netbox:
  file.symlink:
    - target: /opt/netbox-{{ netbox_version }}
    - require:
      - archive: unpack_netbox

/opt/netbox/netbox/media:
  file.directory:
    - user: netbox
    - group: netbox
    - recurse:
      - user
      - group

/opt/netbox/netbox/reports:
  file.directory:
    - user: netbox
    - group: netbox
    - recurse:
      - user
      - group

/opt/netbox/netbox/scripts:
  file.directory:
    - user: netbox
    - group: netbox
    - recurse:
      - user
      - group
