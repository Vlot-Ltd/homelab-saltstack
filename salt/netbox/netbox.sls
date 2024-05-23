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

setup_netbox_config:
  file.managed:
    - name: /opt/netbox/netbox/netbox/configuration.py
    - source: salt://netbox/files/configuration.py.jinja
    - template: jinja
    - context:
        secret_key: {{ pillar['netbox']['secret_key'] }}
        db_password: {{ pillar['netbox']['db_password'] }}
    - user: root
    - group: root
    - mode: 644

config_netbox:
  cmd.run:
    - name: upgrade.sh
    - cwd: /opt/netbox/
    - user: root

collect_static_files:
  cmd.run:
    - name: python3 manage.py collectstatic --no-input
    - cwd: /opt/netbox/netbox
    - user: root
