# salt/application/plex/init.sls
include:
  - .monitoring
  - .maintenance

# Ensure Plex service is running and enabled
plexmediaserver-service:
  service.running:
    - name: plexmediaserver
    - enable: True