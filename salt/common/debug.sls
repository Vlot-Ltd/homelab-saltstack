{% set mine_data_ip = salt['mine.get']('*', 'network.ip_addrs') %}
{% set mine_data_hostname = salt['mine.get']('*', 'network.get_hostname') %}
{% set extra_hosts = pillar.get('extra_hosts', []) %}

# Debug: Write mine_data_ip to /tmp/mine_data_ip.json
debug_mine_data_ip:
  file.managed:
    - name: /tmp/mine_data_ip.json
    - contents: |
        {{ mine_data_ip|tojson }}
    - mode: 644
    - user: root
    - group: root

# Debug: Write mine_data_hostname to /tmp/mine_data_hostname.json
debug_mine_data_hostname:
  file.managed:
    - name: /tmp/mine_data_hostname.json
    - contents: |
        {{ mine_data_hostname|tojson }}
    - mode: 644
    - user: root
    - group: root

# Initialize the hostmap dictionary
{% set hostmap = {} %}

# Process mine data IPs
{% for minion_id, data in mine_data_ip.items() %}
  {% set ip_list = data.get('salt', []) %}
  
  {% set hostname_data = mine_data_hostname.get(minion_id, {}) %}
  {% set hostname = hostname_data.get('salt', [])|first %}
  
  {% if hostname %}
    {% if '.' in hostname %}
      {% set short_hostname = hostname.split('.')[0] %}
      {% set long_hostname = hostname %}
    {% else %}
      {% set short_hostname = hostname %}
      {% set long_hostname = short_hostname ~ '.local' %}
    {% endif %}
  {% else %}
    {% set short_hostname = minion_id %}
    {% set long_hostname = short_hostname ~ '.local' %}
  {% endif %}

  # Debug each minion's processed data
  debug_minion_{{ minion_id }}:
    file.managed:
      - name: /tmp/debug_minion_{{ minion_id }}.txt
      - contents: |
          Minion ID: {{ minion_id }}
          IPs: {{ ip_list|join(', ') }}
          Hostname: {{ hostname }}
          Short Hostname: {{ short_hostname }}
          Long Hostname: {{ long_hostname }}
      - mode: 644
      - user: root
      - group: root

  {% for ip in ip_list %}
    {% set names_to_add = [minion_id, short_hostname, long_hostname] %}
    {% if hostmap.get(ip) is none %}
      {% do hostmap.update({ip: names_to_add}) %}
    {% else %}
      {% for h in names_to_add %}
        {% if h and h not in hostmap[ip] %}
          {% do hostmap[ip].append(h) %}
        {% endif %}
      {% endfor %}
    {% endif %}
  {% endfor %}
{% endfor %}

# Merge extra_hosts data
{% for entry in extra_hosts %}
  {% set ip = entry['ip'] %}
  {% set names = entry['hostnames'] %}
  
  # Debug each extra host entry
  debug_extra_host_{{ ip|replace('.', '_') }}:
    file.managed:
      - name: /tmp/debug_extra_host_{{ ip|replace('.', '_') }}.txt
      - contents: |
          Extra Host IP: {{ ip }}
          Names: {{ names|join(', ') }}
      - mode: 644
      - user: root
      - group: root

  {% if hostmap.get(ip) is none %}
    {% do hostmap.update({ip: names}) %}
  {% else %}
    {% for n in names %}
      {% if n not in hostmap[ip] %}
        {% do hostmap[ip].append(n) %}
      {% endif %}
    {% endfor %}
  {% endif %}
{% endfor %}

# Debug the final hostmap before unique
{% for ip, hostnames in hostmap.items() %}
debug_hostmap_{{ ip|replace('.', '_') }}:
  file.managed:
    - name: /tmp/debug_hostmap_{{ ip|replace('.', '_') }}.txt
    - contents: |
        IP: {{ ip }}
        Hostnames: {{ hostnames|join(', ') }}
    - mode: 644
    - user: root
    - group: root
{% endfor %}

# Manage the /etc/hosts entries
manage_hosts_entries:
  hosts.present:
    - names:
      {% for ip, hostnames in hostmap.items() %}
      - ip: {{ ip }}
        names:
          {% for h in hostnames|unique %}
          - {{ h }}
          {% endfor %}
      {% endfor %}