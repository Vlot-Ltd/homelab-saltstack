base:
  '*':
    - common.schedule
    - common.hosts
  'postgres':
    - postgres
    - application.netbox
    - application.linkwarden
  'docker':
    - application.linkwarden
