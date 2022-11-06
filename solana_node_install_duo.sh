#!/bin/bash
# run by 
# . <(wget -qO- https://raw.githubusercontent.com/Vahhhh/solana/main/solana_node_install_duo.sh)
#set -e -x -v
# Solana node install duo v.0.1
# Made with help of DimAn videos - https://www.youtube.com/c/DimAn_io/ 
# and SecorD0 multitool.sh 0 https://github.com/SecorD0/Monitoring/blob/main/multi_tool.sh

# Default variables

NETWORK=testnet

SOLANA_PATH1="/root/solana"
IDENTITY_PATH1="/root/solana/validator-keypair.json"
VOTE_PATH1="/root/solana/vote-account-keypair.json"

SOLANA_PATH2="/root/solana/solana2"
IDENTITY_PATH2="/root/solana/solana2/validator-keypair.json"
VOTE_PATH2="/root/solana/solana2/vote-account-keypair.json"

#VER_MAINNET=1.10.39
VER_TESTNET=1.14.7
SWAP_PATH="/swapfile"

# Input variables

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

printf "${C_LGn}Enter the nodename1 [node-main]:${RES} "
read -r NODENAME1

printf "${C_LGn}Enter the nodename2 [node-main]:${RES} "
read -r NODENAME2

printf "${C_LGn}Enter SWAP full path [$SWAP_PATH]:${RES} "
read -r SWAP_INPUT
if [ -n "$SWAP_INPUT" ]; then
SWAP_PATH=$SWAP_INPUT
fi

mkdir -p $SOLANA_PATH1
if [ ! -f "$IDENTITY_PATH1" ]; then
printf "${C_LR}Enter your identity private key, the output will not be shown [1,2,3,4,5,6,7,etc]:${RES} "
read -r -s IDENTITY_DATA1
echo $IDENTITY_DATA1 > $IDENTITY_PATH1
echo
fi
if [ ! -f "$VOTE_PATH1" ]; then
printf "${C_LR}Enter your vote private key, the output will not be shown [1,2,3,4,5,6,7,etc]:${RES} "
read -r -s VOTE_DATA1
echo $VOTE_DATA1 > $VOTE_PATH1
echo
fi

mkdir -p $SOLANA_PATH2
if [ ! -f "$IDENTITY_PATH2" ]; then
printf "${C_LR}Enter your identity private key, the output will not be shown [1,2,3,4,5,6,7,etc]:${RES} "
read -r -s IDENTITY_DATA2
echo $IDENTITY_DATA2 > $IDENTITY_PATH2
echo
fi
if [ ! -f "$VOTE_PATH2" ]; then
printf "${C_LR}Enter your vote private key, the output will not be shown [1,2,3,4,5,6,7,etc]:${RES} "
read -r -s VOTE_DATA2
echo $VOTE_DATA1 > $VOTE_PATH2
echo
fi


#: ${value2:=$default1}

apt-get update -y && apt-get install gnupg curl -y && curl -sL https://repos.influxdata.com/influxdb.key | apt-key add - && \
echo "deb https://repos.influxdata.com/ubuntu bionic stable" >> /etc/apt/sources.list.d/influxdata.list && \
apt-get update -y && apt-get upgrade -y && apt-get -y install git telegraf jq bc screen python3-pip && systemctl stop telegraf && pip3 install numpy requests

cd /root/solana

sh -c "$(curl -sSfL https://release.solana.com/v$SOLANAVERSION/install)" && \
export PATH="/root/.local/share/solana/install/active_release/bin:$PATH"

solana config set --url https://api.$NETWORK.solana.com
solana config set --keypair /root/solana/validator-keypair.json

sudo bash -c "cat >/etc/sysctl.d/21-solana-validator.conf <<EOF
# Increase UDP buffer sizes
net.core.rmem_default = 134217728
net.core.rmem_max = 134217728
net.core.wmem_default = 134217728
net.core.wmem_max = 134217728

# Increase memory mapped files limit
vm.max_map_count = 2400000

# Increase number of allowed open file descriptors
fs.nr_open = 2400000
EOF"

sudo sysctl -p /etc/sysctl.d/21-solana-validator.conf

if [ "$NETWORK" == "testnet" ]; then
SWAPSIZE=350
SWAPSIZE2=300
printf '[Unit]
Description=Solana TdS node
After=network.target syslog.target
Wants=solana-sys-tuner.service
StartLimitIntervalSec=0
[Service]
Type=simple
Restart=always
RestartSec=1
LimitNOFILE=2048000
Environment="SOLANA_METRICS_CONFIG=host=https://metrics.solana.com:8086,db=tds,u=testnet_write,p=c4fa841aa918bf8274e3e2a44d77568d9861b3ea"
ExecStart=/root/.local/share/solana/install/active_release/bin/solana-validator \
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
--identity /root/solana/validator-keypair.json \
--vote-account /root/solana/vote-account-keypair.json \
--ledger /root/solana/ledger \
--accounts /mnt/ramdisk/accounts \
--limit-ledger-size 50000000 \
--dynamic-port-range 8000-8020 \
--log /root/solana/solana.log \
--minimal-snapshot-download-speed 20000000 \
--incremental-snapshots \
--maximum-local-snapshot-age 2000 \
--snapshot-compression none \
--private-rpc \
--rpc-port 8899 \
--full-rpc-api
ExecReload=/bin/kill -s HUP $MAINPID
ExecStop=/bin/kill -s QUIT $MAINPID
[Install]
WantedBy=multi-user.target
' > /root/solana/solana.service

printf '[Unit]
Description=Solana TdS node 2
After=network.target syslog.target
Wants=solana-sys-tuner.service
StartLimitIntervalSec=0
[Service]
Type=simple
Restart=always
RestartSec=1
LimitNOFILE=2048000
Environment="SOLANA_METRICS_CONFIG=host=https://metrics.solana.com:8086,db=tds,u=testnet_write,p=c4fa841aa918bf8274e3e2a44d77568d9861b3ea"
ExecStart=/root/.local/share/solana/install/active_release/bin/solana-validator \
--no-snapshot-fetch \
--full-snapshot-interval-slots 0 \
--incremental-snapshot-interval-slots 0 \
--maximum-full-snapshots-to-retain 0 \
--maximum-incremental-snapshots-to-retain 0 \
--snapshots /root/solana/ledger \
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
--identity /root/solana/solana2/validator-keypair.json \
--vote-account /root/solana/solana2/vote-account-keypair.json \
--ledger /root/solana/solana2/ledger \
--accounts /mnt/ramdisk/accounts2 \
--limit-ledger-size 50000000 \
--dynamic-port-range 18000-18020 \
--log /root/solana/solana2/solana.log \
--minimal-snapshot-download-speed 20000000 \
--maximum-local-snapshot-age 2000 \
--snapshot-compression none \
--private-rpc \
--rpc-port 18899 \
--full-rpc-api
ExecReload=/bin/kill -s HUP $MAINPID
ExecStop=/bin/kill -s QUIT $MAINPID
[Install]
WantedBy=multi-user.target
' > /root/solana/solana2/solana2.service
fi

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

cat > /root/solana/solana2/solana2.logrotate <<EOF
/root/solana/solana2/solana.log {
  rotate 7
  daily
  missingok
  postrotate
    systemctl kill -s USR1 solana2.service
  endscript
}
EOF

if [ ! -f $SWAP_PATH ]; then
    swapoff -a
    dd if=/dev/zero of=$SWAP_PATH bs=1G count=$SWAPSIZE
    chmod 600 $SWAP_PATH
    mkswap $SWAP_PATH
    swapon $SWAP_PATH

    # delete other swaps from /etc/fstab
    sed -e '/swap/s/^/#\ /' -i_backup /etc/fstab

    ## add to /etc/fstab
    echo $SWAP_PATH ' none swap sw 0 0' >> /etc/fstab
fi

if [ ! -d "/mnt/ramdisk" ]; then
    # ramdisk
    ## add to /etc/fstab
    echo 'tmpfs /mnt/ramdisk tmpfs nodev,nosuid,noexec,nodiratime,size='$SWAPSIZE2'G 0 0' >> /etc/fstab

    mkdir -p /mnt/ramdisk
    mount /mnt/ramdisk
fi

if [ ! -f "/etc/systemd/system/solana.service" ]; then
    ln -s /root/solana/solana.service /etc/systemd/system
fi

if [ ! -f "/etc/logrotate.d/solana.logrotate" ]; then
    ln -s /root/solana/solana.logrotate /etc/logrotate.d/
fi

if [ ! -f "/etc/systemd/system/solana2.service" ]; then
    ln -s /root/solana/solana2/solana2.service /etc/systemd/system
fi

if [ ! -f "/etc/logrotate.d/solana2.logrotate" ]; then
    ln -s /root/solana/solana2/solana2.logrotate /etc/logrotate.d/
fi

systemctl daemon-reload

systemctl restart logrotate.service

systemctl enable solana.service
systemctl start solana.service

systemctl enable solana2.service
systemctl start solana2.service

adduser telegraf sudo && \
adduser telegraf adm && \
echo "telegraf ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
cp /etc/telegraf/telegraf.conf /etc/telegraf/telegraf.conf.orig && \
rm -rf /etc/telegraf/telegraf.conf && \
# make sure you are the user you run solana with . eq. su - solana

cd /root/solana && git clone https://github.com/stakeconomy/solanamonitoring/ && \
mkdir -p /root/tmp_git && cd $_ && git clone https://github.com/Vahhhh/solana/ || cd solana && git pull && \
cp -r /root/tmp_git/solana/monitoring /root/solana/ && chmod +x /root/solana/monitoring/output_starter.sh && \
cp -r /root/tmp_git/solana/monitoring2 /root/solana/solana2 && mv /root/solana/solana2/monitoring2 /root/solana/solana2/monitoring && \
chmod +x /root/solana/solana2/monitoring/output_starter.sh && cd /root/solana

printf 'from common import ValidatorConfig
config = ValidatorConfig(
    validator_name="%s" ,
    secrets_path="/root/solana",
    local_rpc_address="http://localhost:8899",
    remote_rpc_address="https://api.'$NETWORK'.solana.com",
    cluster_environment="'$NETWORK'",
    debug_mode=False
)
' "$NODENAME1" > /root/solana/monitoring/monitoring_config.py


printf '[agent]
  hostname = "%s" # set this to a name you want to identify your node in the grafana dashboard
  flush_interval = "30s"
  interval = "30s"
  ' "$NODENAME1" > /etc/telegraf/telegraf.conf

# Change config with your nodename

printf '# Input Plugins
[[inputs.cpu]]
    percpu = true
    totalcpu = true
    collect_cpu_time = false
    report_active = false
[[inputs.disk]]
    ignore_fs = ["devtmpfs", "devfs"]
[[inputs.io]]
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
  mount_points = ["/", "/mnt/solana", "/mnt/ramdisk", "/mnt/accounts"]
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


# create telegraf 2
printf '[Unit]
Description=Telegraf2
Documentation=https://github.com/influxdata/telegraf
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
EnvironmentFile=-/etc/default/telegraf
User=telegraf
ExecStart=/usr/bin/telegraf -config /etc/telegraf/telegraf2.conf -config-directory /etc/telegraf/telegraf2.d $TELEGRAF_OPTS
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
RestartForceExitStatus=SIGPIPE
KillMode=control-group

[Install]
WantedBy=multi-user.target

' > /etc/systemd/system/telegraf2.service

systemctl enable telegraf2.service
systemctl start telegraf2.service

cd /root/solana/solana2 && git clone https://github.com/stakeconomy/solanamonitoring/ && \
cp -r /root/tmp_git/solana/monitoring /root/solana/solana2/ && chmod +x /root/solana/solana2/monitoring/output_starter.sh && \
mkdir /etc/telegraf/telegraf2.d && cd /root/solana/solana2

printf 'from common import ValidatorConfig
config = ValidatorConfig(
    validator_name="%s" ,
    secrets_path="/root/solana/solana2",
    local_rpc_address="http://localhost:8899",
    remote_rpc_address="https://api.'$NETWORK'.solana.com",
    cluster_environment="'$NETWORK'",
    debug_mode=False
)
' "$NODENAME2" > /root/solana/solana2/monitoring/monitoring_config.py


printf '[agent]
  hostname = "%s" # set this to a name you want to identify your node in the grafana dashboard
  flush_interval = "30s"
  interval = "30s"
  ' "$NODENAME2" > /etc/telegraf/telegraf2.conf

# Change config with your nodename

printf '# Input Plugins
[[inputs.cpu]]
    percpu = true
    totalcpu = true
    collect_cpu_time = false
    report_active = false
[[inputs.disk]]
    ignore_fs = ["devtmpfs", "devfs"]
[[inputs.io]]
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
  commands = ["sudo su -c /root/solana/solana2/solanamonitoring/monitor.sh -s /bin/bash root"] # change home and username to the useraccount your validator runs at
  interval = "30s"
  timeout = "30s"
  data_format = "influx"
  data_type = "integer"
  ' > /etc/telegraf/telegraf2.d/solanamonitoring2.conf

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
  mount_points = ["/", "/mnt/solana", "/mnt/ramdisk", "/mnt/accounts"]
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
               "sudo -i -u root /root/solana/solana2/monitoring/output_starter.sh output_validator_measurements"
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
  '  > /etc/telegraf/telegraf2.d/thevalidators2.conf 

systemctl restart telegraf
systemctl restart telegraf2

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

systemctl enable fail2ban && systemctl restart fail2ban
sleep 1
iptables -nvL
fail2ban-client status sshd
