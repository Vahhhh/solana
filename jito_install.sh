#!/bin/bash
# . <(wget -qO- https://raw.githubusercontent.com/Vahhhh/solana/main/jito_install.sh)
set -e -x -v

SOLANAVERSION=1.16.23

printf "${C_LGn}Enter the software version [$SOLANAVERSION]:${RES} "
read -r SOLANAVERSION_INPUT
if [ -n "$SOLANAVERSION_INPUT" ]; then
SOLANAVERSION=$SOLANAVERSION_INPUT
fi
export TAG=v$SOLANAVERSION-jito

export IDENTITY_PATH="/root/solana/validator-keypair.json"
export VOTE_PATH="/root/solana/vote-account-keypair.json"

wget -O - https://raw.githubusercontent.com/Vahhhh/solana/main/limits.sh | bash

apt update -y && apt upgrade -y && apt autoremove -y

cd && curl https://sh.rustup.rs -sSf | sh && source $HOME/.cargo/env && \
rustup component add rustfmt && rustup update && \
apt-get install -y libssl-dev libudev-dev pkg-config zlib1g-dev llvm clang cmake make libprotobuf-dev protobuf-compiler && \
git clone https://github.com/jito-foundation/jito-solana.git --recurse-submodules && \
cd jito-solana && \
git checkout tags/$TAG && \
git submodule update --init --recursive && \
CI_COMMIT=$(git rev-parse HEAD) scripts/cargo-install-all.sh --validator-only ~/.local/share/solana/install/releases/"$TAG"

ln -snf /root/.local/share/solana/install/releases/"$TAG" /root/.local/share/solana/install/active_release

export VOTE_ACCOUNT_ADDRESS=$(solana address -k $VOTE_PATH)

cp /root/solana/solana.service.json /root/solana/solana.service.old

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
ExecStart=/root/.local/share/solana/install/active_release/bin/solana-validator \
--no-skip-initial-accounts-db-clean \
--identity /root/solana/validator-keypair.json \
--vote-account %s \
--authorized-voter /root/solana/validator-keypair.json \
--rpc-port 8899 \
--entrypoint 184.105.146.35:8000 \
--entrypoint se1.laine.co.za:8001 \
--entrypoint entrypoint2.mainnet-beta.solana.com:8001 \
--entrypoint entrypoint3.mainnet-beta.solana.com:8001 \
--entrypoint entrypoint4.mainnet-beta.solana.com:8001 \
--log /root/solana/solana.log \
--ledger /root/solana/ledger \
--accounts /root/solana/accounts \
--dynamic-port-range 8001-8050 \
--no-port-check \
--private-rpc \
--rpc-bind-address 127.0.0.1 \
--tower /root/solana/ledger \
--snapshots /root/solana/snapshots \
--no-check-vote-account \
--expected-shred-version 56177 \
--known-validator 7Np41oeYqPefeNQEHSv1UDhYrehxin3NStELsSKCT4K2 \
--known-validator GdnSyH3YtwcxFvQrVVJMm1JhTS4QVX7MFsX56uJLUfiZ \
--known-validator DE1bawNcRJB9rVm3buyMVfr8mBEoyyu73NBovf2oXJsJ \
--known-validator CakcnaRDHka2gXyfbEd2d3xsvkJkqsLw2akB3zsN1D2S \
--only-known-rpc \
--limit-ledger-size \
--wal-recovery-mode skip_any_corrupted_record \
--incremental-snapshots \
--replay-slots-concurrently \
--contact-debug-interval 1000000 \
--minimal-snapshot-download-speed 30000000 \
--rocksdb-shred-compaction fifo \
--tip-payment-program-pubkey T1pyyaTNZsKv2WcRAB8oVnk93mLJw2XzjtVYqCsaHqt \
--tip-distribution-program-pubkey 4R3gSG8BpU4t19KYj8CfnbtRpnT8gtk4dvTHxVRwc2r7 \
--merkle-root-upload-authority GZctHpWXmsZC1YHACTGGcHhYxjdRqQvTpYkb9LMvxDib \
--commission-bps 800 \
--relayer-url http://frankfurt.mainnet.relayer.jito.wtf:8100 \
--block-engine-url https://frankfurt.mainnet.block-engine.jito.wtf \
--shred-receiver-address 145.40.93.84:1002
ExecReload=/bin/kill -s HUP $MAINPID
ExecStop=/bin/kill -s QUIT $MAINPID
[Install]
WantedBy=multi-user.target
' "$VOTE_ACCOUNT_ADDRESS" > /root/solana/solana.service

systemctl daemon-reload

cd ~/tmp_git/solana/ && git pull && cp -r /root/tmp_git/solana/monitoring /root/solana/ && \
mv /root/solana/monitoring/solana_rpc_jito.py /root/solana/monitoring/solana_rpc.py
