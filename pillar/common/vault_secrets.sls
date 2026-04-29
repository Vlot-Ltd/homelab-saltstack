# pillar/vault_secrets.sls
# This file safely references Vault secrets without storing them in Git

homepage_secrets:
  tmdb_api_key: "{{ salt['vault.read_secret']('secret/homepage', 'tmdb_api_key') }}"
  steam_api_key: "{{ salt['vault.read_secret']('secret/homepage', 'steam_api_key') }}"
  steam_user_id: "{{ salt['vault.read_secret']('secret/homepage', 'steam_user_id') }}"

postgres_secrets:
  zabbix_password: "{{ salt['vault.read_secret']('secret/postgres', 'zabbix_password') }}"
  netbox_password: "{{ salt['vault.read_secret']('secret/postgres', 'netbox_password') }}"