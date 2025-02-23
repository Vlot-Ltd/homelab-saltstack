base:
  '*':
    - common.schedule
    - common.extra_hosts
  'postgres':
    - postgres
    - application.netbox
