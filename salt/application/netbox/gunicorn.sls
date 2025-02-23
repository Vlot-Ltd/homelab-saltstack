gunicorn_service:
  file.managed:
    - name: /etc/systemd/system/netbox.service
    - source: salt://netbox/files/netbox.service
    - user: root
    - group: root
    - mode: 644

  service.running:
    - name: netbox
    - enable: True
    - restart: True
    - require:
      - file: gunicorn_service
