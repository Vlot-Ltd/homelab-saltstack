# Reusable macro for creating Tailnet-enabled services
{% macro tailnet_service(service_name, image, env_file=none, volumes=[], extra_config={}) %}

{{ service_name }}-directory:
  file.directory:
    - name: /docker/{{ service_name }}
    - user: root
    - group: docker
    - mode: "0755"

{{ service_name }}-docker-compose:
  file.managed:
    - name: /docker/{{ service_name }}/docker-compose.yml
    - contents: |
        networks:
          tailnet:
            external: true
            name: tailnet

        services:
          {{ service_name }}:
            {% if env_file %}env_file: {{ env_file }}{% endif %}
            restart: always
            image: {{ image }}
            networks:
              - tailnet
            {% if volumes %}
            volumes:
              {% for volume in volumes %}
              - {{ volume }}
              {% endfor %}
            {% endif %}
            {% for key, value in extra_config.items() %}
            {{ key }}: {{ value }}
            {% endfor %}
    - user: root
    - group: docker
    - mode: "0644"

check-{{ service_name }}:
  cmd.run:
    - name: docker ps -f status=running | grep -q {{ service_name }} && echo RUNNING || echo STOPPED
    - output_loglevel: quiet

restart-{{ service_name }}:
  cmd.run:
    - name: docker compose down && docker compose pull && docker compose up -d
    - cwd: /docker/{{ service_name }}
    - onlyif: "grep -q RUNNING /var/cache/salt/minion/check-{{ service_name }}"
    - onchanges:
        - file: {{ service_name }}-docker-compose
    - require:
        - cmd: check-{{ service_name }}

start-{{ service_name }}:
  cmd.run:
    - name: docker compose up -d
    - cwd: /docker/{{ service_name }}
    - onlyif: "grep -q STOPPED /var/cache/salt/minion/check-{{ service_name }}"
    - require:
        - cmd: check-{{ service_name }}
        - cmd: start-tailscale-docker

{% endmacro %}