#!/bin/bash
# install fail2ban
apt -y install fail2ban iptables && \
printf '[DEFAULT]
ignoreip = 93.174.52.0/23
bantime  = 21600
findtime  = 300
maxretry = 3
banaction = iptables-multiport
backend = auto
[sshd]
enabled = true
' > /etc/fail2ban/jail.local && \
systemctl enable fail2ban && systemctl restart fail2ban && \
sleep 1 && \
iptables -nvL && \
fail2ban-client status sshd
