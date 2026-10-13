#!/usr/bin/env bash
set -euo pipefail

export VAULT_ADDR="${VAULT_ADDR:-http://vault.taile3eee.ts.net:8200}"
ROLE_ID_FILE=/etc/friday/vault-role-id
SECRET_ID_FILE=/etc/friday/vault-secret-id

VAULT_TOKEN=$(vault write -field=token auth/approle/login \
  role_id="$(cat "$ROLE_ID_FILE")" \
  secret_id="$(cat "$SECRET_ID_FILE")")

ANTHROPIC_KEY=$(VAULT_TOKEN="$VAULT_TOKEN" vault kv get -field=anthropic_api_key kv/friday)
MASTER_KEY=$(VAULT_TOKEN="$VAULT_TOKEN" vault kv get -field=litellm_master_key kv/friday)

{
  printf 'ANTHROPIC_API_KEY=%s\n' "$ANTHROPIC_KEY"
  printf 'LITELLM_MASTER_KEY=%s\n' "$MASTER_KEY"
} > /run/litellm/secrets.env
chmod 0600 /run/litellm/secrets.env
