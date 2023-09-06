brewupdate:
  cmd.run:
    - name: /usr/bin/arch -arm64 /opt/homebrew/bin/brew update && /usr/bin/arch -arm64 /opt/homebrew/bin/brew upgrade
    - runas: timo
