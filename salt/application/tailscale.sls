tailscale-repo:
  cmd.run:
    - name: >
        curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/$(lsb_release -cs).noarmor.gpg | gpg --dearmor -o /usr/share/keyrings/tailscale-archive-keyring.gpg &&
        echo "deb [signed-by=/usr/share/keyrings/tailscale-archive-keyring.gpg] https://pkgs.tailscale.com/stable/ubuntu $(lsb_release -cs) main" 
        | tee /etc/apt/sources.list.d/tailscale.list
    - creates: /etc/apt/sources.list.d/tailscale.list

tailscale-apt-update:
  cmd.run:
    - name: apt update
    - onchanges:
        - cmd: tailscale-repo

tailscale-install:
  pkg.installed:
    - name: tailscale
    - require:
        - cmd: tailscale-apt-update

tailscale-service:
  service.running:
    - name: tailscaled
    - enable: True
    - require:
        - pkg: tailscale-install

tailscale-auth:
  cmd.run:
    - name: tailscale up --authkey={{ salt['pillar.get']('tailscale_auth_key', '') }}
    - unless: tailscale status | grep -q 'Logged in'
    - require:
        - service: tailscale-service