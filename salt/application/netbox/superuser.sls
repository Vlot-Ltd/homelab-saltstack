create_netbox_superuser:
  cmd.run:
    - name: |
        docker exec -it netbox /opt/netbox/netbox/manage.py shell -c "
        from django.contrib.auth import get_user_model;
        User = get_user_model();
        if not User.objects.filter(username='admin').exists():
            User.objects.create_superuser('admin', '[email protected]', 'yourpassword');
        "
    - unless: |
        docker exec -it netbox /opt/netbox/netbox/manage.py shell -c "
        from django.contrib.auth import get_user_model;
        User = get_user_model();
        exit(0 if User.objects.filter(username='admin').exists() else 1);
        "
    - require:
        - docker_container: netbox
