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

# PEP-HL-SLT-020 / PEP-HL-SLT-006: start only when not all services are
# running; recreate in place on compose/env changes. No down, no pull.
start-{{ service_name }}:
  cmd.run:
    - name: docker compose up -d
    - cwd: /docker/{{ service_name }}
    - unless: 'test "$(docker compose ps -q --status running | wc -l)" -ge "$(docker compose config --services | wc -l)"'
    - require:
        - file: {{ service_name }}-docker-compose
        - cmd: start-tailscale-docker

recreate-{{ service_name }}:
  cmd.run:
    - name: docker compose up -d
    - cwd: /docker/{{ service_name }}
    - onchanges:
        - file: {{ service_name }}-docker-compose
    - require:
        - cmd: start-{{ service_name }}
{% endmacro %}