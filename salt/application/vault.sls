{% set vault_ip = salt['pillar.get']('hosts_entries', {}) | selectattr('name', 'equalto', 'vault') | map(attribute='ip') | first %}

download_hashicorp_gpg_key:
  cmd.run:
    - name: wget -O - https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    - unless: test -f /usr/share/keyrings/hashicorp-archive-keyring.gpg

add_hashicorp_repo:
  pkgrepo.managed:
    - name: deb [arch=amd64 signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com {{ grains['oscodename'] }} main
    - key_url: https://apt.releases.hashicorp.com/gpg
    - file: /etc/apt/sources.list.d/hashicorp.list
    - require_in:
      - pkg: install_vault

install_vault:
  pkg.installed:
    - name: vault
    - version: latest
    - require:
      - pkgrepo: add_hashicorp_gpg_key

vault_config:
  file.managed:
    - name: /etc/vault.d/vault.hcl
    - contents: |
        storage "file" {
          path = "/opt/vault/data"
        }

        listener "tcp" {
          address     = "0.0.0.0:8200"
          tls_disable = true
        }

        api_addr = "http://{{ vault_ip }}:8200"
        cluster_addr = "https://{{ vault_ip }}:8201"
        ui = true
    - user: root
    - group: root
    - mode: 644

vault_service:
  service.running:
    - name: vault
    - enable: True
    - require:
      - pkg: install_vault
      - file: vault_config
