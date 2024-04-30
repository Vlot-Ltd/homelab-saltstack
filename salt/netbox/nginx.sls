nginx_site_configuration:
  file.managed:
    - name: /etc/nginx/sites-available/netbox
    - source: salt://netbox/files/netbox
    - user: root
    - group: root
    - mode: 644

enable_netbox_site:
  file.symlink:
    - name: /etc/nginx/sites-enabled/netbox
    - target: /etc/nginx/sites-available/netbox

restart_nginx_service:
  service.running:
    - name: nginx
    - watch:
      - file: nginx_site_configuration
