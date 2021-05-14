# Some useful information about Solana project

Hope this will be helpful for me and others

Validators registration - https://solana.com/validator-registration

VERY usefull videos about starting Solana node - https://www.youtube.com/c/DimAn_io/videos

My testnet node - https://metrics.stakeconomy.com/d/f2b2HcaGz/solana-community-validator-dashboard?orgId=1&refresh=1m&var-server=vah-stakeiteasy-test&var-inter=30s&var-cpu=All&var-netif=All

Test speed - https://github.com/masonr/yet-another-bench-script/
`curl -sL https://github.com/masonr/yet-another-bench-script/raw/master/yabs.sh | bash -s -- -ig`


My Solana service file without ramdisk
```
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
--entrypoint testnet.solana.com:8001 \
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
--limit-ledger-size 50000000 \
--dynamic-port-range 8000-8010 \
--log /root/solana/solana.log \
--snapshot-interval-slots 500 \
--maximum-local-snapshot-age 500 \
--snapshot-compression none \
--no-port-check \
--rpc-bind-address 127.0.0.1 \
--rpc-port 8899 \
--accounts-db-caching-enabled
ExecReload=/bin/kill -s HUP $MAINPID
ExecStop=/bin/kill -s QUIT $MAINPID
[Install]
WantedBy=multi-user.target
```


**With ramdisk**

```
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
--entrypoint testnet.solana.com:8001 \
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
--maximum-local-snapshot-age 500 \
--snapshot-compression none \
--no-port-check \
--rpc-bind-address 127.0.0.1 \
--rpc-port 8899 \
--accounts-db-caching-enabled
ExecReload=/bin/kill -s HUP $MAINPID
ExecStop=/bin/kill -s QUIT $MAINPID
[Install]
WantedBy=multi-user.target
```
