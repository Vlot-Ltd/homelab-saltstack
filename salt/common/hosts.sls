{% set domain = salt['pillar.get']('default_domain', 'localdomain') %}

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
