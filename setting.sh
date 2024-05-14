#!/bin/bash

cat <<EOF > /etc/netplan/00_static_ip_config.yaml
#network:
  version: 2
  renderer: networkd
  ethernets:
    enp0s3:
      dhcp4: false
      dhcp6: true
      addresses:
      - 192.168.100.122/24
      routes:
      - to: default
        via: 192.168.100.1
      nameservers:
       addresses: [8.8.8.8,1.1.1.1]
EOF

chmod 600 /etc/netplan/00_static_ip_config.yaml
netplan apply