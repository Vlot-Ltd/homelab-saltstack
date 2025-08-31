# Salt policy - broader access for configuration management
path "secret/data/*" {
  capabilities = ["read", "list"]
}
path "auth/token/lookup-self" {
  capabilities = ["read"]
}
