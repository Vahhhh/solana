#!/bin/bash
# run by 
# . <(wget -qO- https://raw.githubusercontent.com/Vahhhh/solana/main/solana_node_install.sh)
# set -e -x -v
# Solana node install v.2.2
# Made with help of DimAn videos - https://www.youtube.com/c/DimAn_io/ 
# and SecorD0 multitool.sh 0 https://github.com/SecorD0/Monitoring/blob/main/multi_tool.sh

# Default variables

# to think about memory autodetect
#if (( $(free | grep Mem: | awk '{ print $2 }') > 500000000 | bc -l ));then echo 1; else echo 0; fi

NETWORK=testnet
CLIENT=solana
SOLANA_PATH="/root/solana"
IDENTITY_PATH="/root/solana/validator-keypair.json"
VOTE_PATH="/root/solana/vote-account-keypair.json"
UNSTAKED_IDENTITY_PATH="/root/solana/unstaked-identity.json"
VER_MAINNET="$(wget -q -4 -O- https://api.margus.one/solana/version/?cluster=mainnet)"
VER_TESTNET="$(wget -q -4 -O- https://api.margus.one/solana/version/?cluster=testnet)"
SWAP_PATH="/swapfile"
ACCOUNTS_PATH="/mnt/ramdisk/accounts"
ACCOUNTS_INDEX_PATH="/mnt/ramdisk/accounts_index"
ACCOUNTS_HASH_CACHE_PATH="/mnt/ramdisk/accounts_hash_cache"
LEDGER_PATH="/mnt/ledger"
SNAPSHOTS_PATH="/mnt/snapshots"

# Input variables

printf "${C_LGn}Enter the Solana client (solana/JITO/Ari) [s/J/a]:${RES} "
read -r CLIENT
case "$CLIENT" in
    [sS]) 
        CLIENT=solana
        ;;
    [aA]) 
        CLIENT=ari
        ;;
    *)
        CLIENT=jito
        ;;
esac

printf "${C_LGn}Enter the network (mainnet/testnet) [m/T]:${RES} "
read -r NETWORK
case "$NETWORK" in
    [mM]) 
        NETWORK=mainnet-beta
        SOLANAVERSION=$VER_MAINNET
        ;;
    *)
        NETWORK=testnet
        SOLANAVERSION=$VER_TESTNET
        ;;
esac

printf "${C_LGn}Enter the software version [$SOLANAVERSION]:${RES} "
read -r SOLANAVERSION_INPUT
if [ -n "$SOLANAVERSION_INPUT" ]; then
SOLANAVERSION=$SOLANAVERSION_INPUT
fi

printf "${C_LGn}Enter the nodename [node-main]:${RES} "
read -r NODENAME

printf "${C_LGn}Enter SWAP full path [$SWAP_PATH]:${RES} "
read -r SWAP_INPUT
if [ -n "$SWAP_INPUT" ]; then
SWAP_PATH=$SWAP_INPUT
fi

printf "${C_LGn}Enter ACCOUNTS full path [$ACCOUNTS_PATH]:${RES} "
read -r ACCOUNTS_INPUT
if [ -n "$ACCOUNTS_INPUT" ]; then
ACCOUNTS_PATH=$ACCOUNTS_INPUT
fi

printf "${C_LGn}Enter ACCOUNTS_INDEX_PATH full path [$ACCOUNTS_INDEX_PATH]:${RES} "
read -r ACCOUNTS_INDEX_INPUT
if [ -n "$ACCOUNTS_INDEX_INPUT" ]; then
ACCOUNTS_INDEX_PATH=$ACCOUNTS_INDEX_INPUT
fi

printf "${C_LGn}Enter ACCOUNTS_HASH_CACHE_PATH full path [$ACCOUNTS_HASH_CACHE_PATH]:${RES} "
read -r ACCOUNTS_HASH_CACHE_INPUT
if [ -n "$ACCOUNTS_HASH_CACHE_INPUT" ]; then
ACCOUNTS_HASH_CACHE_PATH=$ACCOUNTS_HASH_CACHE_INPUT
fi

printf "${C_LGn}Enter LEDGER full path [$LEDGER_PATH]:${RES} "
read -r LEDGER_INPUT
if [ -n "$LEDGER_INPUT" ]; then
LEDGER_PATH=$LEDGER_INPUT
fi

printf "${C_LGn}Enter SNAPSHOTS full path [$SNAPSHOTS_PATH]:${RES} "
read -r SNAPSHOTS_INPUT
if [ -n "$SNAPSHOTS_INPUT" ]; then
SNAPSHOTS_PATH=$SNAPSHOTS_INPUT
fi

mkdir -p $SOLANA_PATH
if [ ! -f "$IDENTITY_PATH" ]; then
printf "${C_LR}Enter your identity private key, the output will not be shown [1,2,3,4,5,6,7,etc]:${RES} "
read -r -s IDENTITY_DATA
echo $IDENTITY_DATA > $IDENTITY_PATH
fi

echo

if [ ! -f "$VOTE_PATH" ]; then
printf "${C_LR}Enter your vote private key, the output will not be shown [1,2,3,4,5,6,7,etc]:${RES} "
read -r -s VOTE_DATA
echo $VOTE_DATA > $VOTE_PATH
fi

if [ "$NETWORK" == "mainnet-beta" ]; then
SWAPSIZE=300
SWAPSIZE2=250
elif [ "$NETWORK" == "testnet" ]; then
SWAPSIZE=160
SWAPSIZE2=120
fi

printf "${C_LGn}Enter the swap size [$SWAPSIZE]:${RES} "
read -r SWAPSIZE_INPUT
if [ -n "$SWAPSIZE_INPUT" ]; then
SWAPSIZE=$SWAPSIZE_INPUT
fi

printf "${C_LGn}Enter the ramdisk size [$SWAPSIZE2]:${RES} "
read -r SWAPSIZE2_INPUT
if [ -n "$SWAPSIZE2_INPUT" ]; then
SWAPSIZE2=$SWAPSIZE2_INPUT
fi

if [[ $(grep -c telegram_bot_token /root/.profile) == 0 ]]; then
printf "${C_LGn}Enter the Telegram bot token:${RES} "
read -r TELEGRAM_BOT_TOKEN

printf "${C_LGn}Enter the Telegram chat id:${RES} "
read -r TELEGRAM_CHAT_ID
fi

timedatectl set-timezone Europe/Moscow && echo "LANG=C.UTF-8" > /etc/default/locale
sudo sed -i 's/#$nrconf{restart} = '"'"'i'"'"';/$nrconf{restart} = '"'"'a'"'"';/g' /etc/needrestart/needrestart.conf
echo '* libraries/restart-without-asking boolean true' | sudo debconf-set-selections
sed -i 's/week/dai/g' /lib/systemd/system/fstrim.timer && sed -i 's/week/dai/g' /etc/systemd/system/timers.target.wants/fstrim.timer
systemctl daemon-reload && systemctl restart fstrim.timer && systemctl restart fstrim.service

ln -sf /root/solana/validator-keypair.json /root/solana/identity.json

cat > /root/solana/solana.logrotate <<EOF
/root/solana/solana.log {
  rotate 7
  daily
  missingok
  postrotate
    systemctl kill -s USR1 solana.service
  endscript
}
EOF

printf "${C_LGn}Should we create SWAP one more time? [Y/n]:${RES} "
read -r SWAP_CREATE_INPUT
case "$SWAP_CREATE_INPUT" in
    [nN]) 
    echo "not creating swap one more time"
        ;;
    *)
    swapoff -a
    dd if=/dev/zero of=$SWAP_PATH bs=1G count=$SWAPSIZE
    chmod 600 $SWAP_PATH
    mkswap $SWAP_PATH
    swapon $SWAP_PATH

    # delete other swaps from /etc/fstab
    sed -e '/swap/s/^/#\ /' -i_backup /etc/fstab

    ## add to /etc/fstab
    echo $SWAP_PATH ' none swap sw 0 0' >> /etc/fstab
        ;;
esac


#if [ ! -f $SWAP_PATH ]; then
#fi

if [ ! -d "/mnt/ramdisk" ]; then
    # ramdisk
    ## add to /etc/fstab
    echo 'tmpfs /mnt/ramdisk tmpfs nodev,nosuid,noexec,nodiratime,size='$SWAPSIZE2'G 0 0' >> /etc/fstab

    mkdir -p /mnt/ramdisk
    mount /mnt/ramdisk
fi


echo ""

apt-get update -y && apt-get install wget gnupg curl gpg chrony -y && \
gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys D8FF8E1F7DF8B07E && \
gpg --export D8FF8E1F7DF8B07E | sudo tee /etc/apt/trusted.gpg.d/influxdb.gpg > /dev/null && \
echo "deb [signed-by=/etc/apt/trusted.gpg.d/influxdb.gpg] https://repos.influxdata.com/ubuntu jammy stable" > /etc/apt/sources.list.d/influxdata.list

apt-get update -y && apt-get upgrade -y && apt-get -y install linux-tools-common linux-tools-generic cpufrequtils git telegraf jq bc screen python3-pip && systemctl stop telegraf && pip3 install numpy requests

wget -O - https://raw.githubusercontent.com/Vahhhh/solana/main/limits.sh | bash

echo 'GOVERNOR="performance"' | sudo tee /etc/default/cpufrequtils
systemctl disable ondemand
cpupower frequency-set -g performance

solana config set --url https://api.$NETWORK.solana.com
solana config set --keypair /root/solana/validator-keypair.json

if [ "$CLIENT" == "solana" ]; then
cd /root/solana

if [ "$NETWORK" == "mainnet-beta" ]; then
printf '[Unit]
Description=Solana Mainnet node
After=network.target syslog.target
StartLimitIntervalSec=0
[Service]
Type=simple
Restart=always
RestartSec=1
LimitNOFILE=2048000
Environment="SOLANA_METRICS_CONFIG=host=https://metrics.solana.com:8086,db=mainnet-beta,u=mainnet-beta_write,p=password"
ExecStartPre=/usr/bin/ln -sf /root/solana/unstaked-identity.json /root/solana/identity.json
ExecStartPost=bash -c "/root/solana/post_restart_solana.sh &"
ExecStart=/root/.local/share/solana/install/active_release/bin/solana-validator \
#--no-skip-initial-accounts-db-clean \
--entrypoint entrypoint.mainnet-beta.solana.com:8001 \
--entrypoint entrypoint2.mainnet-beta.solana.com:8001 \
--entrypoint entrypoint3.mainnet-beta.solana.com:8001 \
--entrypoint entrypoint4.mainnet-beta.solana.com:8001 \
--entrypoint entrypoint5.mainnet-beta.solana.com:8001 \
--expected-genesis-hash 5eykt4UsFv8P8NJdTREpY1vzqKqZKvdpKuc147dw2N9d \
--known-validator 7Np41oeYqPefeNQEHSv1UDhYrehxin3NStELsSKCT4K2 \
--known-validator GdnSyH3YtwcxFvQrVVJMm1JhTS4QVX7MFsX56uJLUfiZ \
--known-validator DE1bawNcRJB9rVm3buyMVfr8mBEoyyu73NBovf2oXJsJ \
--known-validator CakcnaRDHka2gXyfbEd2d3xsvkJkqsLw2akB3zsN1D2S \
--wal-recovery-mode skip_any_corrupted_record \
--identity /root/solana/identity.json \
--vote-account /root/solana/vote-account-keypair.json \
--authorized-voter /root/solana/validator-keypair.json \
--ledger '$LEDGER_PATH' \
--accounts '$ACCOUNTS_PATH' \
--tower '$LEDGER_PATH' \
--snapshots '$SNAPSHOTS_PATH' \
--accounts-hash-cache-path /mnt/ramdisk/accounts_hash_cache \
--accounts-hash-interval-slots 2500 \
--full-snapshot-interval-slots 50000 \
--incremental-snapshot-interval-slots 2500 \
--limit-ledger-size 50000000 \
--dynamic-port-range 8000-8020 \
--log /root/solana/solana.log \
--minimal-snapshot-download-speed 20000000 \
--maximum-local-snapshot-age 3000 \
--private-rpc \
--rpc-port 8899 \
--full-rpc-api
ExecReload=/bin/kill -s HUP $MAINPID
ExecStop=/bin/kill -s QUIT $MAINPID
[Install]
WantedBy=multi-user.target
' > /root/solana/solana.service

# --accounts-hash-cache-path /mnt/ramdisk/accounts_hash_cache \
# --accounts-index-path /mnt/ramdisk/accounts_index \

sh -c "$(curl -sSfL https://release.solana.com/v$SOLANAVERSION/install)" && \
export PATH="/root/.local/share/solana/install/active_release/bin:$PATH"


elif [ "$NETWORK" == "testnet" ]; then
printf '[Unit]
Description=Solana TdS node
After=network.target syslog.target
StartLimitIntervalSec=0
[Service]
Type=simple
Restart=always
RestartSec=1
LimitNOFILE=2048000
Environment="SOLANA_METRICS_CONFIG=host=https://metrics.solana.com:8086,db=tds,u=testnet_write,p=c4fa841aa918bf8274e3e2a44d77568d9861b3ea"
ExecStartPre=/usr/bin/ln -sf /root/solana/unstaked-identity.json /root/solana/identity.json
ExecStartPost=bash -c "/root/solana/post_restart_solana.sh &"
ExecStart=/root/.local/share/solana/install/active_release/bin/agave-validator \
#--no-skip-initial-accounts-db-clean \
--entrypoint entrypoint3.testnet.solana.com:8001 \
--entrypoint entrypoint2.testnet.solana.com:8001 \
--entrypoint entrypoint.testnet.solana.com:8001 \
--known-validator 5D1fNXzvv5NjV1ysLjirC4WY92RNsVH18vjmcszZd8on \
--known-validator dDzy5SR3AXdYWVqbDEkVFdvSPCtS9ihF5kJkHCtXoFs \
--known-validator Ft5fbkqNa76vnsjYNwjDZUXoTWpP7VYm3mtsaQckQADN \
--known-validator eoKpUABi59aT4rR9HGS3LcMecfut9x7zJyodWWP43YQ \
--known-validator 9QxCLckBiJc783jnMvXZubK4wH86Eqqvashtrwvcsgkv \
--expected-genesis-hash 4uhcVJyU9pJkvQyS88uRDiswHXSCkY3zQawwpjk2NsNY \
--wal-recovery-mode skip_any_corrupted_record \
--identity /root/solana/identity.json \
--vote-account /root/solana/vote-account-keypair.json \
--authorized-voter /root/solana/validator-keypair.json \
--ledger '$LEDGER_PATH' \
--accounts '$ACCOUNTS_PATH' \
--tower '$LEDGER_PATH' \
--snapshots '$SNAPSHOTS_PATH' \
#--accounts-hash-cache-path /mnt/ramdisk/accounts_hash_cache \
--accounts-hash-interval-slots 2500 \
--full-snapshot-interval-slots 50000 \
--incremental-snapshot-interval-slots 2500 \
--limit-ledger-size 50000000 \
--dynamic-port-range 8000-8020 \
--log /root/solana/solana.log \
--minimal-snapshot-download-speed 20000000 \
--maximum-local-snapshot-age 2000 \
--private-rpc \
--rpc-port 8899 \
--full-rpc-api
ExecReload=/bin/kill -s HUP $MAINPID
ExecStop=/bin/kill -s QUIT $MAINPID
[Install]
WantedBy=multi-user.target
' > /root/solana/solana.service

sh -c "$(curl -sSfL https://release.anza.com/v$SOLANAVERSION/install)" && \
export PATH="/root/.local/share/solana/install/active_release/bin:$PATH"

fi

elif [ "$CLIENT" == "jito" ]; then

TAG=v$SOLANAVERSION-jito
cd && curl https://sh.rustup.rs -sSf | sh && source $HOME/.cargo/env && \
rustup component add rustfmt && rustup update && \
apt-get install -y libssl-dev libudev-dev pkg-config zlib1g-dev llvm clang cmake make libprotobuf-dev protobuf-compiler && \

git clone https://github.com/jito-foundation/jito-solana.git --recurse-submodules && \
cd jito-solana && \
git checkout tags/$TAG && \
git submodule update --init --recursive && \
CI_COMMIT=$(git rev-parse HEAD) scripts/cargo-install-all.sh --validator-only ~/.local/share/solana/install/releases/"$TAG"

ln -snf /root/.local/share/solana/install/releases/"$TAG" /root/.local/share/solana/install/active_release
export PATH="/root/.local/share/solana/install/active_release/bin:$PATH"
echo 'export PATH="/root/.local/share/solana/install/active_release/bin:$PATH"' >> /root/.profile
source ~/.profile

solana config set --url https://api.$NETWORK.solana.com
solana config set --keypair /root/solana/validator-keypair.json

VOTE_ACCOUNT_ADDRESS=$(solana address -k $VOTE_PATH)

if [ "$NETWORK" == "mainnet-beta" ]; then
printf '[Unit]
Description=Solana Mainnet node
After=network.target syslog.target
StartLimitIntervalSec=0
[Service]
Type=simple
Restart=always
RestartSec=1
LimitNOFILE=2048000
Environment="SOLANA_METRICS_CONFIG=host=https://metrics.solana.com:8086,db=mainnet-beta,u=mainnet-beta_write,p=password"
ExecStartPre=/usr/bin/ln -sf /root/solana/unstaked-identity.json /root/solana/identity.json
ExecStartPost=bash -c "/root/solana/post_restart_solana.sh &"
ExecStart=/root/.local/share/solana/install/active_release/bin/solana-validator \
#--no-skip-initial-accounts-db-clean \
--identity /root/solana/identity.json \
--vote-account /root/solana/vote-account-keypair.json \
--authorized-voter /root/solana/validator-keypair.json \
--entrypoint entrypoint.mainnet-beta.solana.com:8001 \
--entrypoint entrypoint2.mainnet-beta.solana.com:8001 \
--entrypoint entrypoint3.mainnet-beta.solana.com:8001 \
--entrypoint entrypoint4.mainnet-beta.solana.com:8001 \
--known-validator 7Np41oeYqPefeNQEHSv1UDhYrehxin3NStELsSKCT4K2 \
--known-validator GdnSyH3YtwcxFvQrVVJMm1JhTS4QVX7MFsX56uJLUfiZ \
--known-validator DE1bawNcRJB9rVm3buyMVfr8mBEoyyu73NBovf2oXJsJ \
--known-validator CakcnaRDHka2gXyfbEd2d3xsvkJkqsLw2akB3zsN1D2S \
--log /root/solana/solana.log \
--ledger '$LEDGER_PATH' \
--accounts '$ACCOUNTS_PATH' \
--accounts-hash-cache-path '$ACCOUNTS_HASH_CACHE_PATH' \
--accounts-index-path '$ACCOUNTS_INDEX_PATH' \
--tower '$LEDGER_PATH' \
--snapshots '$SNAPSHOTS_PATH' \
--incremental-snapshot-archive-path '$SNAPSHOTS_PATH' \
--dynamic-port-range 8001-8050 \
--private-rpc \
--rpc-bind-address 127.0.0.1 \
--rpc-port 8899 \
--full-rpc-api \
--only-known-rpc \
--maximum-full-snapshots-to-retain 1 \
--maximum-incremental-snapshots-to-retain 2 \
--use-snapshot-archives-at-startup when-newest \
--accounts-hash-interval-slots 2500 \
--full-snapshot-interval-slots 50000 \
--incremental-snapshot-interval-slots 2500 \
--maximum-local-snapshot-age 3000 \
--minimal-snapshot-download-speed 30000000 \
--limit-ledger-size \
--wal-recovery-mode skip_any_corrupted_record \
--tip-payment-program-pubkey T1pyyaTNZsKv2WcRAB8oVnk93mLJw2XzjtVYqCsaHqt \
--tip-distribution-program-pubkey 4R3gSG8BpU4t19KYj8CfnbtRpnT8gtk4dvTHxVRwc2r7 \
--merkle-root-upload-authority GZctHpWXmsZC1YHACTGGcHhYxjdRqQvTpYkb9LMvxDib \
--commission-bps 800 \
--account-index program-id \
--account-index-include-key AddressLookupTab1e1111111111111111111111111 \
#--relayer-url http://127.0.0.1:11226 \
--relayer-url http://ny.mainnet.relayer.jito.wtf:8100 \
--block-engine-url https://ny.mainnet.block-engine.jito.wtf \
--shred-receiver-address 141.98.216.96:1002
ExecReload=/bin/kill -s HUP $MAINPID
ExecStop=/bin/kill -s QUIT $MAINPID
[Install]
WantedBy=multi-user.target
' > /root/solana/solana.service
fi
fi

if [ ! -f "/etc/systemd/system/solana.service" ]; then
    ln -s /root/solana/solana.service /etc/systemd/system
fi

if [ ! -f "/etc/logrotate.d/solana.logrotate" ]; then
    ln -s /root/solana/solana.logrotate /etc/logrotate.d/
fi

if [ ! -f "$UNSTAKED_IDENTITY_PATH" ]; then
solana-keygen new -s --no-bip39-passphrase -o $UNSTAKED_IDENTITY_PATH
fi
ln -sf /root/solana/unstaked-identity.json /root/solana/identity.json

wget -O /root/solana/post_restart_solana.sh https://raw.githubusercontent.com/Vahhhh/solana/main/post_restart_solana.sh && chmod +x /root/solana/post_restart_solana.sh
sed -i "s/NODE_NAME=\"\"/NODE_NAME=\"$NODENAME\"/g" /root/solana/post_restart_solana.sh
sed -i "s/telegram_bot_token=\"\"/telegram_bot_token=\"$TELEGRAM_BOT_TOKEN\"/g" /root/solana/post_restart_solana.sh
sed -i "s/telegram_chat_id=\"\"/telegram_chat_id=\"$TELEGRAM_CHAT_ID\"/g" /root/solana/post_restart_solana.sh
if [[ $(grep -c telegram_bot_token /root/.profile) == 0 ]]; then
echo "telegram_bot_token=\"$TELEGRAM_BOT_TOKEN\"" >> /root/.profile
echo "telegram_chat_id=\"$TELEGRAM_CHAT_ID\"" >> /root/.profile
fi

systemctl daemon-reload

systemctl restart logrotate.service

systemctl enable solana.service
systemctl start solana.service


adduser telegraf sudo && \
adduser telegraf adm && \
echo "telegraf ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
cp /etc/telegraf/telegraf.conf /etc/telegraf/telegraf.conf.orig && \
rm -rf /etc/telegraf/telegraf.conf && \
# make sure you are the user you run solana with . eq. su - solana
cd /root/solana && git clone https://github.com/stakeconomy/solanamonitoring/ && \
mkdir -p /root/tmp_git && cd $_ && git clone https://github.com/Vahhhh/solana/ && \
cp -r /root/tmp_git/solana/monitoring /root/solana/ && chmod +x /root/solana/monitoring/output_starter.sh && cd /root/solana

# this error solved adding full-api key to jito
#if [ "$CLIENT" == "jito" ]; then
#mv /root/solana/monitoring/solana_rpc_jito.py /root/solana/monitoring/solana_rpc.py
#fi

printf 'from common import ValidatorConfig
config = ValidatorConfig(
    validator_name="%s" ,
    secrets_path="/root/solana",
    local_rpc_address="http://localhost:8899",
    remote_rpc_address="https://api.'$NETWORK'.solana.com",
    cluster_environment="'$NETWORK'",
    debug_mode=False
)
' "$NODENAME" > /root/solana/monitoring/monitoring_config.py


printf '[agent]
  hostname = "%s" # set this to a name you want to identify your node in the grafana dashboard
  flush_interval = "30s"
  interval = "30s"
  ' "$NODENAME" > /etc/telegraf/telegraf.conf

# Change config with your nodename

printf '# Input Plugins
[[inputs.cpu]]
    percpu = true
    totalcpu = true
    collect_cpu_time = false
    report_active = false
[[inputs.disk]]
    ignore_fs = ["devtmpfs", "devfs"]
#[[inputs.io]]
[[inputs.mem]]
[[inputs.net]]
[[inputs.system]]
[[inputs.swap]]
[[inputs.netstat]]
[[inputs.processes]]
[[inputs.kernel]]
[[inputs.diskio]]
# Output Plugin InfluxDB
[[outputs.influxdb]]
  database = "metricsdb"
  urls = [ "http://metrics.stakeconomy.com:8086" ] # keep this to send all your metrics to the community dashboard otherwise use http://yourownmonitoringnode:8086
  username = "metrics" # keep both values if you use the community dashboard
  password = "password"
[[inputs.exec]]
  commands = ["sudo su -c /root/solana/solanamonitoring/monitor.sh -s /bin/bash root"] # change home and username to the useraccount your validator runs at
  interval = "30s"
  timeout = "30s"
  data_format = "influx"
  data_type = "integer"
  ' > /etc/telegraf/telegraf.d/solanamonitoring.conf

printf '##INPUTS
[[inputs.cpu]]
  ## Whether to report per-cpu stats or not
  percpu = false
  ## Whether to report total system cpu stats or not
  totalcpu = true
  ## If true, collect raw CPU time metrics.
  collect_cpu_time = false
  ## If true, compute and report the sum of all non-idle CPU states.
  report_active = false
[[inputs.disk]]
  ## By default stats will be gathered for all mount points.
  ## Set mount_points will restrict the stats to only the specified mount points.
  mount_points = ["/", "/mnt/ledger", "/mnt/solana/ramdisk/accounts"]
  ## Ignore mount points by filesystem type.
  ignore_fs = ["devtmpfs", "devfs", "iso9660", "overlay", "aufs", "squashfs"]
[[inputs.diskio]]
[[inputs.net]]
[[inputs.nstat]]
[[inputs.procstat]]
 pattern="solana"
[[inputs.system]]
[[inputs.systemd_units]]
    [inputs.systemd_units.tagpass]
    name = ["solana*"]
[[inputs.mem]]
[[inputs.swap]]
[[inputs.exec]]
  commands = [
               "sudo -i -u root /root/solana/monitoring/output_starter.sh output_validator_measurements"
             ]
  interval = "30s"
  timeout = "30s"
  json_name_key = "measurement"
  json_time_key = "time"
  tag_keys = ["tags_validator_name",
              "tags_validator_identity_pubkey",
              "tags_validator_vote_pubkey",
              "tags_cluster_environment",
              "validator_id",
              "validator_name"]
  json_string_fields = [
            "monitoring_version",
            "solana_version",
            "validator_identity_pubkey",
            "validator_vote_pubkey",
            "cluster_environment",
            "cpu_model"]
  json_time_format = "unix_ms"
##OUPUTS
[[outputs.influxdb]]
  database = "v_metrics"
  urls = [ "http://influx.thevalidators.io:8086", "http://mon.stakeiteasy.ru:8086" ]
  username = "v_user"
  password = "thepassword"
  '  > /etc/telegraf/telegraf.d/thevalidators.conf  

systemctl restart telegraf

apt-get -y install fail2ban iptables

printf '[DEFAULT]
ignoreip = 93.174.52.0/23
bantime  = 21600
findtime  = 300
maxretry = 3
banaction = iptables-multiport
backend = auto
[sshd]
enabled = true
' > /etc/fail2ban/jail.local

if [ ! -f "/var/log/auth.log" ]; then
apt-get install -y rsyslog
touch /var/log/auth.log
fi

systemctl enable fail2ban && systemctl restart fail2ban
sleep 1
iptables -nvL
fail2ban-client status sshd
