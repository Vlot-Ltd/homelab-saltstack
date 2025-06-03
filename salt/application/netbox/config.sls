{% set postgres_host = salt['pillar.get']('hosts_entries', []) | selectattr('name', 'equalto', 'postgres') | list | first %}
{% set postgres_ip = postgres_host['ip'] if postgres_host and 'ip' in postgres_host else 'postgres' %}
{% set db_info = salt['pillar.get']('postgres_databases', []) | selectattr('name', 'equalto', 'netbox') | list | first %}
{% set db_user = db_info['users'][0]['name'] if db_info and 'users' in db_info else 'netbox_user' %}
{% set db_password = db_info['users'][0]['password'] if db_info and 'users' in db_info else 'netbox_securepassword' %}
{% set netbox_secret = salt['pillar.get']('netbox_secret', 'banananananas') %}
{% set superuser_email = salt['pillar.get']('superuser_email', '') %}
{% set superuser_password = salt['pillar.get']('superuser_password', 'banananananas') %}

/opt/netbox/netbox/netbox/configuration.py:
  file.managed:
    - source: salt://application/netbox/files/configuration.py.jinja
    - template: jinja
    - required_by:
      - cmd: /opt/netbox/upgrade.sh

 /opt/netbox/upgrade.sh:
   cmd.run

create_superuser:
  cmd.run:
    - name: /opt/netbox/netbox/manage.py shell -c "
        from django.contrib.auth import get_user_model;
        User = get_user_model();
        if not User.objects.filter(username='admin').exists():
            User.objects.create_superuser('admin', '{{ superuser_email }}', '{{ superuser_password }}');
        "
    - unless: |
        /opt/netbox/netbox/manage.py shell -c "
        from django.contrib.auth import get_user_model;
        User = get_user_model();
        exit(0 if User.objects.filter(username='admin').exists() else 1);
        "