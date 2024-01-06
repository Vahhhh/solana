#!/bin/bash
# . <(wget -qO- https://raw.githubusercontent.com/Vahhhh/solana/main/jito_install.sh)
#set -e -x -v

SOLANAVERSION="$(wget -q -4 -O- https://api.margus.one/solana/version/?cluster=mainnet)"

printf "${C_LGn}Enter the software version [$SOLANAVERSION]:${RES} "
read -r SOLANAVERSION_INPUT
if [ -n "$SOLANAVERSION_INPUT" ]; then
SOLANAVERSION=$SOLANAVERSION_INPUT
fi
export TAG=v$SOLANAVERSION-jito

ACCOUNTS_PATH="/root/solana/accounts"
LEDGER_PATH="/root/solana/ledger"
SNAPSHOTS_PATH="/root/solana/snapshots"

printf "${C_LGn}Enter ACCOUNTS full path [$ACCOUNTS_PATH]:${RES} "
read -r ACCOUNTS_INPUT
if [ -n "$ACCOUNTS_INPUT" ]; then
ACCOUNTS_PATH=$ACCOUNTS_INPUT
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

cp /root/solana/solana.service /root/solana/solana.service.old

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
--identity /root/solana/identity.json \
--vote-account %s \
--authorized-voter /root/solana/validator-keypair.json \
--entrypoint 184.105.146.35:8000 \
--entrypoint se1.laine.co.za:8001 \
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
--tower '$LEDGER_PATH' \
--snapshots '$SNAPSHOTS_PATH' \
--accounts-hash-cache-path /mnt/ramdisk/accounts_hash_cache \
--dynamic-port-range 8001-8050 \
--private-rpc \
--rpc-bind-address 127.0.0.1 \
--rpc-port 8899 \
--full-rpc-api \
--only-known-rpc \
--maximum-full-snapshots-to-retain 2 \
--maximum-incremental-snapshots-to-retain 3 \
--accounts-hash-interval-slots 2500 \
--full-snapshot-interval-slots 25000 \
--incremental-snapshot-interval-slots 2500 \
--maximum-local-snapshot-age 3000 \
--minimal-snapshot-download-speed 30000000 \
--limit-ledger-size \
--wal-recovery-mode skip_any_corrupted_record \
--replay-slots-concurrently \
--contact-debug-interval 1000000 \
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

#cd ~/tmp_git/solana/ && git pull && cp -r /root/tmp_git/solana/monitoring /root/solana/ && \
#mv /root/solana/monitoring/solana_rpc_jito.py /root/solana/monitoring/solana_rpc.py
