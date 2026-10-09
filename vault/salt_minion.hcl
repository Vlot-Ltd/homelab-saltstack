# Vault policy: salt_minion
# Assigned to every minion's AppRole by vault.conf (policies: assign: salt_minion).
# Apply: vault policy write salt_minion vault/salt_minion.hcl
#
# Paths are templated on the minion's identity entity metadata, which the
# master writes from vault.conf (metadata: entity: minion-id / roles). A list
# pillar value is stored as roles__0, roles__1, ... After changing a minion's
# roles pillar, run: salt-run vault.sync_entities

# Shared secrets
path "salt/data/general" {
    capabilities = ["read"]
}

path "salt/data/general/*" {
    capabilities = ["read"]
}

# Per-minion secrets
path "salt/data/minions/{{identity.entity.metadata.minion-id}}" {
    capabilities = ["read"]
}

# Per-role secrets (up to four roles per minion)
path "salt/data/roles/{{identity.entity.metadata.roles__0}}" {
    capabilities = ["read"]
}

path "salt/data/roles/{{identity.entity.metadata.roles__1}}" {
    capabilities = ["read"]
}

path "salt/data/roles/{{identity.entity.metadata.roles__2}}" {
    capabilities = ["read"]
}

path "salt/data/roles/{{identity.entity.metadata.roles__3}}" {
    capabilities = ["read"]
}
