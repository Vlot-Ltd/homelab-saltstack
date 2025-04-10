vim:
  pkg:
    - installed

'/usr/bin/update-alternatives --set editor /usr/bin/vim.basic':
  cmd.run:
    - unless:  ls -all /etc/alternatives/editor | grep vim.basic
