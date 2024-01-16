#!/bin/bash
# wget -O - https://raw.githubusercontent.com/Vahhhh/solana/main/limits.sh | bash

grep 'vm.swappiness = 10' /etc/sysctl.conf || bash -c "echo 'vm.swappiness = 10' >> /etc/sysctl.conf"

bash -c "cat >/etc/sysctl.d/21-solana-validator.conf <<EOF
# Increase UDP buffer sizes
net.core.rmem_default = 134217728
net.core.rmem_max = 134217728
net.core.wmem_default = 134217728
net.core.wmem_max = 134217728

# Increase memory mapped files limit
vm.max_map_count = 2048000

# Increase number of allowed open file descriptors
fs.nr_open = 2048000
EOF"

sysctl -p /etc/sysctl.d/21-solana-validator.conf
sysctl -p

bash -c "cat >/etc/security/limits.d/90-solana-nofiles.conf <<EOF
# Increase process file descriptor count limit
* - nofile 2048000
EOF"
