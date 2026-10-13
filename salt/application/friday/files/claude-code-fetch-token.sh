#!/usr/bin/env bash
set -euo pipefail

export VAULT_ADDR="${VAULT_ADDR:-http://vault.taile3eee.ts.net:8200}"
ROLE_ID_FILE=/etc/friday/vault-role-id
SECRET_ID_FILE=/etc/friday/vault-secret-id

VAULT_TOKEN=$(vault write -field=token auth/approle/login \
  role_id="$(cat "$ROLE_ID_FILE")" \
  secret_id="$(cat "$SECRET_ID_FILE")")

OAUTH_TOKEN=$(VAULT_TOKEN="$VAULT_TOKEN" vault kv get -field=claude_token kv/friday)

printf 'CLAUDE_CODE_OAUTH_TOKEN=%s\n' "$OAUTH_TOKEN" > /run/claude-code/token.env
chmod 0600 /run/claude-code/token.env
