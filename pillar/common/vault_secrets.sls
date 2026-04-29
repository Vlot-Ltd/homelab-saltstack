# pillar/vault_secrets.sls
# This file safely references Vault secrets without storing them in Git

homepage_secrets:
  tmdb_api_key: {{ pillar.get('tmdb_api_key', '') }}
  steam_api_key: {{ pillar.get('steam_api_key', '') }}
  steam_user_id: {{ pillar.get('steam_user_id', '') }}

postgres_secrets:
  zabbix_password: {{ pillar.get('zabbix_password', '') }}
  netbox_password: {{ pillar.get('netbox_password', '') }}