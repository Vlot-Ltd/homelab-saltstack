{% set mine_hosts = salt['mine.get']('*', 'network.ip_addrs', 'network.get_hostname') %}
{% set extra_hosts = pillar.get('extra_hosts', []) %}

{% set all_hosts = [] %}

{% for minion_id, data in mine_hosts.items() %}
  {% set ip_addrs = data.get('network.ip_addrs', []) %}
  {% set hostname = data.get('network.get_hostname', '') %}
  {% set short_hostname = hostname.split('.')[0] if '.' in hostname else hostname %}
  {% for ip in ip_addrs %}
    {% set host_entry = {
      'ip': ip,
      'hostnames': [hostname, short_hostname, minion_id]
    } %}
    {% do all_hosts.append(host_entry) %}
  {% endfor %}
{% endfor %}

{% for host in extra_hosts %}
  {% do all_hosts.append(host) %}
{% endfor %}

{% set unique_hosts = {} %}
{% for host in all_hosts %}
  {% set ip = host['ip'] %}
  {% if ip not in unique_hosts %}
    {% do unique_hosts.update({ip: host['hostnames']}) %}
  {% else %}
    {% do unique_hosts[ip].extend(host['hostnames']) %}
  {% endif %}
{% endfor %}

{% for ip, hostnames in unique_hosts.items() %}
  {% set unique_hostnames = hostnames|unique %}
  {% do unique_hosts.update({ip: unique_hostnames}) %}
{% endfor %}

manage_hosts_entries:
  hosts.present:
    - names:
        {% for ip, hostnames in unique_hosts.items() %}
        - ip: {{ ip }}
          names:
            {% for name in hostnames %}
            - {{ name }}
            {% endfor %}
        {% endfor %}