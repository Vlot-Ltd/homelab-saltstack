zabbix-repo:
  cmd.run:
    - name: >
        wget -qO- https://repo.zabbix.com/zabbix-official-repo.key | gpg --dearmor -o /usr/share/keyrings/zabbix-official-repo.gpg &&
        echo "deb [signed-by=/usr/share/keyrings/zabbix-official-repo.gpg] https://repo.zabbix.com/zabbix/7.2/ubuntu/ $(lsb_release -cs) main" 
        | tee /etc/apt/sources.list.d/zabbix.list
    - creates: /etc/apt/sources.list.d/zabbix.list
