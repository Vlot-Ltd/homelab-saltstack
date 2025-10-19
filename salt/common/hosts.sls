{% set domain = salt['pillar.get']('default_domain', 'localdomain') %}
{% set docker_host_ip = salt['pillar.get']('docker:host_tailscale_ip', '100.x.x.x') %}

{% for entry in salt['pillar.get']('hosts_entries', []) %}
{{ entry.name }}-host:
  host.present:
    - name: {{ entry.name }}
    - ip: {{ entry.ip }}
    - clean: True

{{ entry.name }}-fqdn:
  host.present:
    - name: {{ entry.name }}.{{ domain }}
    - ip: {{ entry.ip }}
    - clean: True
{% endfor %}

{% for service_name, service_data in salt['pillar.get']('docker:services', {}).items() %}
{{ service_data.container }}-host:
  host.present:
    - name: {{ service_data.container }}
    - ip: {{ docker_host_ip }}
    - clean: True

{{ service_data.container }}-fqdn:
  host.present:
    - name: {{ service_data.container }}.{{ domain }}
    - ip: {{ docker_host_ip }}
    - clean: True
{% endfor %}
