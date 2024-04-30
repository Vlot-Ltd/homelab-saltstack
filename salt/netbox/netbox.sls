clone_netbox_repo:
  git.latest:
    - name: https://github.com/netbox-community/netbox.git
    - target: /opt/netbox
    - rev: master
    - force_reset: True
    - user: root

install_netbox_requirements:
  pip.installed:
    - bin_env: /usr/bin/pip3
    - requirements: /opt/netbox/requirements.txt

generate_netbox_secret_key:
  cmd.run:
    - name: python3 /opt/netbox/netbox/generate_secret_key.py
    - cwd: /opt/netbox
    - output: grain
    - grain: netbox_secret_key

setup_netbox_config:
  file.managed:
    - name: /opt/netbox/netbox/netbox/configuration.py
    - source: salt://netbox/files/configuration.py.jinja
    - template: jinja
    - context:
        secret_key: {{ grains['netbox_secret_key'] }}
        db_password: {{ pillar['netbox']['db_password'] }}
    - user: root
    - group: root
    - mode: 644
    - require:
      - cmd: generate_netbox_secret_key

migrate_database:
  cmd.run:
    - name: python3 manage.py migrate
    - cwd: /opt/netbox/netbox
    - user: root

collect_static_files:
  cmd.run:
    - name: python3 manage.py collectstatic --no-input
    - cwd: /opt/netbox/netbox
    - user: root
