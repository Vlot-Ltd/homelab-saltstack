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

{% for service in  salt['pillar.get']('docker:services', {}) %}
{{ service.container }}-host:
  host.present:
    - name: {{ service.container }}
    - ip: {{ docker_host_ip }}
    - clean: True

{{ service.container }}-fqdn:
  host.present:
    - name: {{ service.container }}.{{ domain }}
    - ip: {{ docker_host_ip }}
    - clean: True
{% endfor %}
