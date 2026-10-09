# Vault policy: salt-master
# Attached to the salt-master AppRole (auth/approle/role/salt-master).
# Apply: vault policy write salt-master vault/salt-master.hcl
#
# The master issues each minion its own AppRole on auth/salt-minions/
# (vault.conf: issue: type: approle), so it needs to manage those roles and
# their identity entities as well as read secrets.

# Read secrets on the salt/ KV v2 mount
path "salt/*" {
  capabilities = ["read", "list"]
}

# Self-lookup
path "auth/token/lookup-self" {
  capabilities = ["read"]
}

# Issue tokens for minions
path "auth/token/create" {
  capabilities = ["create", "read", "update"]
}
path "auth/token/create/*" {
  capabilities = ["create", "read", "update"]
}

# Manage per-minion AppRoles on the salt-minions/ mount
path "auth/salt-minions/role" {
  capabilities = ["list"]
}
path "auth/salt-minions/role/*" {
  capabilities = ["read", "create", "update", "delete"]
}

# Look up the salt-minions mount accessor (for entity aliases)
path "sys/auth/salt-minions" {
  capabilities = ["read", "sudo"]
}

# Manage minion identity entities and aliases
path "identity/entity/name/salt_minion_*" {
  capabilities = ["read", "create", "update", "delete"]
}
path "identity/entity-alias" {
  capabilities = ["create", "update"]
}

# Entity lookup by alias (salt-run vault.sync_entities)
path "identity/lookup/entity" {
  capabilities = ["create", "update"]
}
