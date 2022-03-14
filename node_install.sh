# Solana node install v.1.0
# Made with help of DimAn videos - https://www.youtube.com/c/DimAn_io/

# hostname=solana-1
# solanaversion=v1.9.9

apt update -y && apt upgrade -y && apt install curl gnupg git -y

echo $hostname > /etc/hostname
hostname $hostname

### reconnect

solanaversion=v1.9.9

mkdir -p /root/solana
cd /root/solana

### add the file ~/solana/validator-keypair.json by
### nano ~/solana/validator-keypair.json and COPY-PASTE
### or by copying the file from another host by SCP for example
### if you are making reinstall, then add also ~/solana/vote-account-keypair.json and don't create it later again!

sh -c "$(curl -sSfL https://release.solana.com/$solanaversion/install)" && \
export PATH="/root/.local/share/solana/install/active_release/bin:$PATH"

solana --version && \
solana config set --url https://api.testnet.solana.com && \
solana transaction-count 

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


### Create swapfile if hasn't been created before

# swapfile
## create swapfile
swapoff -a && \
dd if=/dev/zero of=/swapfile bs=1G count=64 && \
chmod 600 /swapfile && \
mkswap /swapfile && \
swapon /swapfile && \

## add to /etc/fstab
echo '/swapfile none swap sw 0 0' >> /etc/fstab  && \

# ramdisk
## add to /etc/fstab
echo 'tmpfs /mnt/ramdisk tmpfs nodev,nosuid,noexec,nodiratime,size=64G 0 0' >> /etc/fstab  && \

# delete other swaps from /etc/fstab

mkdir -p /mnt/ramdisk && \
mount /mnt/ramdisk

# add to solana.service
#--accounts /mnt/ramdisk/accounts


### Close all open sessions (log out then, in again) ###

solana config set --keypair ~/solana/validator-keypair.json

solana-keygen new -o ~/solana/vote-account-keypair.json

solana create-vote-account -v --authorized-withdrawer ~/solana/validator-keypair.json --commission 100 -k ~/solana/validator-keypair.json s ~/solana/vote-account-keypair.json ~/solana/validator-keypair.json

printf '[Unit]
Description=Solana TdS node
After=network.target syslog.target
Wants=solana-sys-tuner.service
StartLimitIntervalSec=0
[Service]
Type=simple
Restart=always
RestartSec=1
LimitNOFILE=1024000
Environment="SOLANA_METRICS_CONFIG=host=https://metrics.solana.com:8086,db=tds,u=testnet_write,p=c4fa841aa918bf8274e3e2a44d77568d9861b3ea"
ExecStartPre=/usr/bin/systemctl restart solana-sys-tuner
ExecStart=/root/.local/share/solana/install/active_release/bin/solana-validator \
--entrypoint entrypoint3.testnet.solana.com:8001 \
--entrypoint entrypoint2.testnet.solana.com:8001 \
--entrypoint entrypoint.testnet.solana.com:8001 \
--entrypoint api.testnet.solana.com:8001 \
--known-validator 5D1fNXzvv5NjV1ysLjirC4WY92RNsVH18vjmcszZd8on \
--known-validator 7XSY3MrYnK8vq693Rju17bbPkCN3Z7KvvfvJx4kdrsSY \
--known-validator Ft5fbkqNa76vnsjYNwjDZUXoTWpP7VYm3mtsaQckQADN \
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
--full-snapshot-interval-slots 20000 \
--incremental-snapshot-interval-slots 1000 \
--maximum-full-snapshots-to-retain 2 \
--maximum-incremental-snapshots-to-retain 4 \
--maximum-local-snapshot-age 2000 \
--snapshot-compression none \
--private-rpc \
--rpc-port 8899 \
--accounts-db-caching-enabled
ExecReload=/bin/kill -s HUP $MAINPID
ExecStop=/bin/kill -s QUIT $MAINPID
[Install]
WantedBy=multi-user.target
' > /root/solana/solana.service


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

ln -s /root/solana/solana.service /etc/systemd/system
ln -s /root/solana/solana.logrotate /etc/logrotate.d/

systemctl daemon-reload

systemctl restart logrotate.service

# if you have error 'error: skipping "/var/log/debug" because parent directory has insecure permissions' run the following
# chmod 755 /var/log/ && chown root:root /var/log/

systemctl enable solana.service
systemctl start solana.service

tail -f /root/solana/solana.log

ll /root/solana/ledger/

solana catchup /root/solana/validator-keypair.json --our-localhost



# Monitoring

# install telegraf
cat <<EOF | tee /etc/apt/sources.list.d/influxdata.list
deb https://repos.influxdata.com/ubuntu bionic stable
EOF

curl -sL https://repos.influxdata.com/influxdb.key | apt-key add -

apt-get update && apt-get -y install telegraf jq bc && systemctl stop telegraf && apt install python3-pip -y && pip3 install numpy requests && \

# make the telegraf user and sudo adm to be able to execute scripts as sol user
adduser telegraf sudo && \
adduser telegraf adm && \
echo "telegraf ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

cp /etc/telegraf/telegraf.conf /etc/telegraf/telegraf.conf.orig
rm -rf /etc/telegraf/telegraf.conf

# make sure you are the user you run solana with . eq. su - solana

cd /root/solana && git clone https://github.com/stakeconomy/solanamonitoring/ && \
mkdir -p /root/tmp_git && cd $_ && git clone https://github.com/Vahhhh/solana/ && \
cp -r /root/tmp_git/solana/monitoring /root/solana/ && chmod +x /root/solana/monitoring/output_starter.sh && cd /root/solana


# !!! CHANGE THIS NODENAME !!!
read -p 'Enter nodename for monitoring: ' nodename

printf 'from common import ValidatorConfig

config = ValidatorConfig(
    validator_name="%s" ,
    secrets_path="/root/solana",
    local_rpc_address="http://localhost:8899",
    remote_rpc_address="https://api.testnet.solana.com",
    cluster_environment="testnet",
    debug_mode=False
)
' "$nodename" > /root/solana/monitoring/monitoring_config.py && \


printf '[agent]
  hostname = "%s" # set this to a name you want to identify your node in the grafana dashboard
  flush_interval = "30s"
  interval = "30s"
  ' "$nodename" > /etc/telegraf/telegraf.conf && \

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
  urls = [ "http://influx.thevalidators.io:8086" ]
  username = "v_user"
  password = "thepassword"
  '  > /etc/telegraf/telegraf.d/thevalidators.conf  

systemctl restart telegraf


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



# configure fw
sudo ufw reset

sudo ufw allow 22/tcp
sudo ufw allow 8000:8020/tcp
sudo ufw allow 8000:8020/udp

sudo ufw enable

# Check https://metrics.stakeconomy.com/


#### donate if it was helpful

SOL - `2Y4C2e5d6bUY1nb5mqFfkSCyAt39K7cYEim2gD7vAtKC`

LTC - `MAaitfT32P9CZdQApTf6Mm4WZygakkGmg6`

BTC - `36N8gkZ19Doem8hXv6GL7xXVuQv8aDMmoX`
