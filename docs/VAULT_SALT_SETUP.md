# Vault-Salt Integration Setup

## Overview
Configure Salt to securely retrieve the Tailscale auth key from HashiCorp Vault.

## 1. Vault Configuration

### Enable KV Secrets Engine (if not already enabled)
```bash
vault secrets enable -path=secret kv-v2
```

### Store Tailscale Auth Key
```bash
# Generate a reusable auth key in Tailscale admin console first
vault kv put secret/tailscale auth_key="tskey-auth-your-key-here"
```

### Create Policy for Salt
```bash
vault policy write salt-policy - <<EOF
path "secret/data/tailscale" {
  capabilities = ["read"]
}
path "secret/data/homepage" {
  capabilities = ["read"]
}
path "secret/data/*" {
  capabilities = ["read"]
}
EOF
```

### Create AppRole for Salt
```bash
# Enable AppRole auth
vault auth enable approle

# Create role for Salt
vault write auth/approle/role/salt \
    token_policies="salt-policy" \
    token_ttl=1h \
    token_max_ttl=4h \
    bind_secret_id=true

# Get role-id (save this)
vault read auth/approle/role/salt/role-id

# Generate secret-id (save this)
vault write -f auth/approle/role/salt/secret-id
```

## 2. Salt Configuration

### Add to Salt Master Config (/etc/salt/master or /etc/salt/master.d/vault.conf)
```yaml
# Vault configuration
vault:
  url: http://your-vault-server:8200
  auth:
    method: approle
    role_id: "your-role-id-here"
    secret_id: "your-secret-id-here"
  policies: ["salt-policy"]

# Required for minion Vault access
peer_run:
  - vault.generate_token
  - vault.get_config

# Enable Vault external pillar (if using vault in pillar files)
ext_pillar:
  - vault:
      conf:
        url: http://your-vault-server:8200
        auth:
          method: approle
          role_id: "your-role-id-here"
          secret_id: "your-secret-id-here"
```

### Alternative: Environment Variables
```bash
export VAULT_ADDR="http://your-vault-server:8200"
export VAULT_ROLE_ID="your-role-id-here"
export VAULT_SECRET_ID="your-secret-id-here"
```

### Test Vault Integration
```bash
# Test from Salt master
salt-call vault.read_secret secret/data/tailscale auth_key

# Should return: tskey-auth-your-key-here
```

## 3. Update Pillar (Optional Cleanup)

### Remove from pillar files
Remove any hardcoded `tailscale_auth_key` entries from your pillar files since we're now using Vault.

## 4. Apply Changes

```bash
# Restart Salt master after config changes
systemctl restart salt-master

# Test Vault integration from master
salt-call vault.read_secret secret/data/tailscale auth_key

# Test from minion
salt 'docker' vault.read_secret secret/data/tailscale auth_key

# Apply the updated Tailscale Docker state
salt 'docker' state.apply application.tailscale-docker

# Verify container has auth key
salt 'docker' cmd.run 'docker logs tailscale-sidecar | grep -i auth'
```

## Security Notes

- Store role-id and secret-id securely
- Consider using Salt's encrypted pillar for role/secret IDs if needed
- Rotate secret-id periodically
- Monitor Vault audit logs for Salt access

## Troubleshooting

### Common Issues
1. **Config not loaded**: If `salt-call config.get vault` returns nothing:
   - Check file location: `/etc/salt/master.d/vault.conf`
   - Verify YAML syntax (spaces not tabs)
   - Ensure file permissions are readable
   - Check file extension is `.conf`
2. **Pillar render error**: "vault is not a valid Vault ext_pillar config":
   - Add `ext_pillar` section to master config
   - Don't use `{{ salt['vault.read_secret']() }}` in pillar files
   - Use `vault.read_secret()` directly in SLS files instead
3. **Connection refused**: Check Vault URL and network connectivity
4. **Permission denied**: Verify policy allows read access to secret paths
5. **Invalid credentials**: Regenerate secret-id if expired
6. **Empty auth key**: Check secret path and key name in Vault

### Debug Commands
```bash
# 1. Check Vault status
vault status

# 2. Verify Salt master config is loaded
salt-call config.get vault
salt-call config.get peer_run

# 3. Test direct Vault access from master
salt-call --local vault.read_secret secret/data/tailscale auth_key

# 4. Check if peer_run is working
salt-call peer.run salt vault.get_config

# 5. List secrets
vault kv list secret/

# 6. Read secret directly from Vault
vault kv get secret/tailscale

# 7. Check Salt master logs for errors
journalctl -u salt-master -f
```

### Configuration Verification
```bash
# Check if vault.conf exists and is readable
ls -la /etc/salt/master.d/vault.conf
cat /etc/salt/master.d/vault.conf

# Check YAML syntax
python3 -c "import yaml; yaml.safe_load(open('/etc/salt/master.d/vault.conf'))"

# Verify master configuration loads without errors
salt-call config.validate_config /etc/salt/master

# Test if Salt can find config files
ls -la /etc/salt/master.d/

# Check Salt master logs for config errors
journalctl -u salt-master | grep -i vault
```