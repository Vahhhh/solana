#!/bin/bash
# Solana node install v.2.0
# Made with help of DimAn videos - https://www.youtube.com/c/DimAn_io/ 
# and SecorD0 multitool.sh 0 https://github.com/SecorD0/Monitoring/blob/main/multi_tool.sh

# Default variables

NETWORK=testnet
SOLANA_PATH="/root/solana"
IDENTITY_PATH="/root/solana/validator-keypair.json"
VOTE_PATH="/root/solana/vote-account-keypair.json"

# Input variables

printf "${C_LGn}Enter the network [mainnet-beta/testnet]:${RES} "
read -r NETWORK
printf "${C_LGn}Enter the software version [1.10.12]:${RES} "
read -r SOLANAVERSION

mkdir -p $SOLANA_PATH
if [ ! -f "$IDENTITY_PATH" ]; then
printf "${C_LR}Enter your identity private key, the output will not be shown [1,2,3,4,5,6,7,etc]:${RES} "
read -r -s IDENTITY_DATA
echo $IDENTITY_DATA > $IDENTITY_PATH
fi
if [ ! -f "$VOTE_PATH" ]; then
printf "${C_LR}Enter your vote private key, the output will not be shown [1,2,3,4,5,6,7,etc]:${RES} "
read -r -s VOTE_DATA
echo $VOTE_DATA > $VOTE_PATH
fi


#: ${value2:=$default1}

apt update -y && apt install curl -y && curl -sL https://repos.influxdata.com/influxdb.key | apt-key add - && \
echo "deb https://repos.influxdata.com/ubuntu bionic stable" >> /etc/apt/sources.list.d/influxdata.list && \
apt update -y && apt upgrade -y && apt -y install gnupg git telegraf jq bc screen python3-pip && systemctl stop telegraf && pip3 install numpy requests

cd /root/solana

### add the file ~/solana/validator-keypair.json by
### nano ~/solana/validator-keypair.json and COPY-PASTE
### or by copying the file from another host by SCP for example
### if you are making reinstall, then add also ~/solana/vote-account-keypair.json and don't create it later again!

sh -c "$(curl -sSfL https://release.solana.com/$solanaversion/install)" && \
export PATH="/root/.local/share/solana/install/active_release/bin:$PATH"

solana config set --url https://api.$NETWORK.solana.com

# let's try to test sys-tuner
printf '[Unit]
Description=Solana System Tuner Service
After=network.target syslog.target
StartLimitIntervalSec=0

[Service]
Type=simple
Restart=always
RestartSec=1
ExecStart=/root/.local/share/solana/install/active_release/bin/solana-sys-tuner --user root

[Install]
WantedBy=multi-user.target
' > /etc/systemd/system/solana-sys-tuner.service

systemctl enable solana-sys-tuner.service
systemctl start solana-sys-tuner.service

