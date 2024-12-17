{# Retrieve mine data: minion_id -> { 'network.ip_addrs': [...], 'network.get_hostname': '...' } #}
{% set mine_data = salt['mine.get']('*', ['network.ip_addrs', 'network.get_hostname']) %}
{% set extra_hosts = pillar.get('extra_hosts', []) %}

{# Initialize a dictionary: ip -> list_of_hostnames #}
{% set hostmap = {} %}

{# Process mine data from each minion #}
{% for minion_id, data in mine_data.items() %}
  {% set ip_list = data.get('network.ip_addrs', []) %}
  {% set hostname = data.get('network.get_hostname', '') %}

  {% if '.' in hostname %}
    {% set short_hostname = hostname.split('.')[0] %}
    {% set long_hostname = hostname %}
  {% else %}
    {% set short_hostname = hostname %}
    {% set long_hostname = short_hostname ~ '.local' %}
  {% endif %}

  {# For each IP, add minion_id, short_hostname, and long_hostname #}
  {% for ip in ip_list %}
    {% set names_to_add = [minion_id, short_hostname, long_hostname] %}

    {% if ip not in hostmap %}
      {% set hostmap.update({ip: names_to_add}) %}
    {% else %}
      {% for h in names_to_add %}
        {% if h and h not in hostmap[ip] %}
          {% do hostmap[ip].append(h) %}
        {% endif %}
      {% endfor %}
    {% endif %}
  {% endfor %}
{% endfor %}

{# Merge extra_hosts data #}
{% for entry in extra_hosts %}
  {% set ip = entry['ip'] %}
  {% set names = entry['hostnames'] %}
  {% if ip not in hostmap %}
    {% set hostmap.update({ip: names}) %}
  {% else %}
    {% for n in names %}
      {% if n not in hostmap[ip] %}
        {% do hostmap[ip].append(n) %}
      {% endif %}
    {% endfor %}
  {% endif %}
{% endfor %}

{# Deduplicate hostnames per IP #}
{% for ip, hostnames in hostmap.items() %}
  {% set unique_hostnames = hostnames|unique %}
  {% set hostmap[ip] = unique_hostnames %}
{% endfor %}

manage_hosts_entries:
  hosts.present:
    - names:
      {% for ip, hostnames in hostmap.items() %}
      - ip: {{ ip }}
        names:
          {% for h in hostnames %}
          - {{ h }}
          {% endfor %}
      {% endfor %}