{% set mine_conf = '/etc/salt/minion.d/mine_functions.conf' %}

mine_functions_config:
  file.managed:
    - name: {{ mine_conf }}
    - source: salt://common/files/mine_functions.conf
    - user: root
    - group: root
    - mode: 0644

mine_update:
  module.run:
    - name: mine.update
    - onchanges:
      - file: mine_functions_config