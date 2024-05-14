#!/bin/bash

PRIVATE_IP_ADDRESS=192.168.100.
DEFAULT_GATEWAY=192.168.100.1

cat <<EOF > /etc/netplan/99_static_ip_config.yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    ens18:
      dhcp4: false
      dhcp6: true
      addresses:
      - ${PRIVATE_IP_ADDRESS}/24
      routes:
      - to: default
        via: ${DEFAULT_GATEWAY}
      nameservers:
       addresses: [8.8.8.8,1.1.1.1]
EOF

chmod 600 /etc/netplan/99_static_ip_config.yaml
netplan apply
reboot
