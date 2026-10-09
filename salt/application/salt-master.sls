# Salt master extensions.
#
# Since Salt 3007, Vault support lives in the saltext-vault extension, installed
# with salt-pip into onedir's per-Python extras directory
# (/opt/saltstack/salt/extras-3.X). When a Salt upgrade bumps onedir's Python
# (3.10 -> 3.14 by 3008), the extension is left behind in the old directory and
# every Vault ext_pillar lookup fails with "ext_pillar interface named vault is
# unavailable". Pinning it here reinstalls it on the next highstate.
# See PEP-HL-SLT-008.
{% set saltext_vault_version = '1.8.0' %}

saltext-vault:
  cmd.run:
    - name: salt-pip install saltext-vault=={{ saltext_vault_version }}
    - unless: salt-pip list 2>/dev/null | grep -qE '^saltext\.vault +{{ saltext_vault_version | replace('.', '\.') }}$'

# The master only loads extensions at start. Restart in the background so the
# state run that triggered it can still return.
saltext-vault-restart-master:
  cmd.run:
    - name: sleep 5 && systemctl restart salt-master
    - bg: True
    - onchanges:
        - cmd: saltext-vault
