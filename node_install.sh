# Solana node install v.1.0
# Made with help of DimAn videos - https://www.youtube.com/c/DimAn_io/

hostname=solana-1
solanaversion=v1.6.10

apt update -y && apt upgrade -y && apt install curl gnupg git -y

echo $hostname > /etc/hostname
hostname $hostname

### reconnect

hostname=solana-1
solanaversion=v1.6.10

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
solana transaction-count && \
solana-gossip spy --entrypoint entrypoint.testnet.solana.com:8001

bash -c "cat >/etc/sysctl.d/20-solana-udp-buffers.conf <<EOF
# Increase UDP buffer size
net.core.rmem_default = 134217728
net.core.rmem_max = 134217728
net.core.wmem_default = 134217728
net.core.wmem_max = 134217728
EOF"

bash -c "cat >/etc/sysctl.d/20-solana-mmaps.conf <<EOF
# Increase memory mapped files limit
vm.max_map_count = 700000
EOF"

bash -c "cat >/etc/security/limits.d/90-solana-nofiles.conf <<EOF
# Increase process file descriptor count limit
* - nofile 700000
EOF"

sysctl -p /etc/sysctl.d/20-solana-udp-buffers.conf
sysctl -p /etc/sysctl.d/20-solana-mmaps.conf
systemctl daemon-reload


### Create swapfile if hasn't been created before

# swapfile
## create swapfile
swapoff -a && \
dd if=/dev/zero of=/swapfile bs=1G count=128 && \
chmod 600 /swapfile && \
mkswap /swapfile && \
swapon /swapfile && \

## add to /etc/fstab
echo '/swapfile none swap sw 0 0' >> /etc/fstab  && \

# ramdisk
## add to /etc/fstab
echo 'tmpfs /mnt/ramdisk tmpfs nodev,nosuid,noexec,nodiratime,size=100G 0 0' >> /etc/fstab  && \

# delete other swaps from /etc/fstab

mkdir -p /mnt/ramdisk && \
mount /mnt/ramdisk

# add to solana.service
#--accounts /mnt/ramdisk/accounts


### Close all open sessions (log out then, in again) ###

solana config set --keypair ~/solana/validator-keypair.json

solana-keygen new -o ~/solana/vote-account-keypair.json

solana create-vote-account ~/solana/vote-account-keypair.json ~/solana/validator-keypair.json

cat > /root/solana/solana.service <<EOF
[Unit]
Description=Solana TdS node
After=network.target syslog.target
StartLimitIntervalSec=0
[Service]
Type=simple
Restart=always
RestartSec=1
LimitNOFILE=1024000
Environment="SOLANA_METRICS_CONFIG=host=https://metrics.solana.com:8086,db=tds,u=testnet_write,p=c4fa841aa918bf8274e3e2a44d77568d9861b3ea"
ExecStart=/root/.local/share/solana/install/active_release/bin/solana-validator \
--entrypoint entrypoint3.testnet.solana.com:8001 \
--entrypoint entrypoint2.testnet.solana.com:8001 \
--entrypoint entrypoint.testnet.solana.com:8001 \
--entrypoint api.testnet.solana.com:8001 \
--trusted-validator 5D1fNXzvv5NjV1ysLjirC4WY92RNsVH18vjmcszZd8on \
--trusted-validator 7XSY3MrYnK8vq693Rju17bbPkCN3Z7KvvfvJx4kdrsSY \
--trusted-validator Ft5fbkqNa76vnsjYNwjDZUXoTWpP7VYm3mtsaQckQADN \
--trusted-validator 9QxCLckBiJc783jnMvXZubK4wH86Eqqvashtrwvcsgkv \
--expected-genesis-hash 4uhcVJyU9pJkvQyS88uRDiswHXSCkY3zQawwpjk2NsNY \
--no-untrusted-rpc \
--wal-recovery-mode skip_any_corrupted_record \
--identity /root/solana/validator-keypair.json \
--vote-account /root/solana/vote-account-keypair.json \
--ledger /root/solana/ledger \
--accounts /mnt/ramdisk/accounts \
--limit-ledger-size 50000000 \
--dynamic-port-range 8000-8010 \
--log /root/solana/solana.log \
--snapshot-interval-slots 500 \
--maximum-local-snapshot-age 1000 \
--snapshot-compression none \
--no-port-check \
--rpc-bind-address 127.0.0.1 \
--rpc-port 8899 \
--accounts-db-caching-enabled
ExecReload=/bin/kill -s HUP $MAINPID
ExecStop=/bin/kill -s QUIT $MAINPID
[Install]
WantedBy=multi-user.target
EOF


cat > /root/solana/solana.logrotate <<EOF
/root/solana/solana-validator.log {
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

journalctl -u solana.service


ll /root/solana/ledger/

solana catchup /root/solana/validator-keypair.json --our-localhost



# Monitoring

# install telegraf
cat <<EOF | tee /etc/apt/sources.list.d/influxdata.list
deb https://repos.influxdata.com/ubuntu bionic stable
EOF

curl -sL https://repos.influxdata.com/influxdb.key | apt-key add -

apt-get update
apt-get -y install telegraf jq bc

systemctl enable --now telegraf
systemctl is-enabled telegraf
systemctl stop telegraf
systemctl status telegraf

# make the telegraf user and sudo adm to be able to execute scripts as sol user
adduser telegraf sudo
adduser telegraf adm
echo "telegraf ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

cp /etc/telegraf/telegraf.conf /etc/telegraf/telegraf.conf.orig
rm -rf /etc/telegraf/telegraf.conf

# make sure you are the user you run solana with . eq. su - solana

cd /root/solana && git clone https://github.com/stakeconomy/solanamonitoring/
```

# Change config with your nodename
```
cat > /etc/telegraf/telegraf.conf <<EOF
# Global Agent Configuration
[agent]
  hostname = "nodename-testnet" # set this to a name you want to identify your node in the grafana dashboard
  flush_interval = "15s"
  interval = "15s"

# Input Plugins
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
EOF
```

```
systemctl restart telegraf
```

Check https://metrics.stakeconomy.com/


#### donate if it was helpful

SOL - `2Y4C2e5d6bUY1nb5mqFfkSCyAt39K7cYEim2gD7vAtKC`

LTC - `MAaitfT32P9CZdQApTf6Mm4WZygakkGmg6`

BTC - `36N8gkZ19Doem8hXv6GL7xXVuQv8aDMmoX`
