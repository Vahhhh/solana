#!/bin/bash
# wget -O - https://raw.githubusercontent.com/Vahhhh/solana/main/jito_update.sh | bash
set -e -x -v

SOLANAVERSION=1.16.23

printf "${C_LGn}Enter the software version [$SOLANAVERSION]:${RES} "
read -r SOLANAVERSION_INPUT
if [ -n "$SOLANAVERSION_INPUT" ]; then
SOLANAVERSION=$SOLANAVERSION_INPUT
fi
export TAG=v$SOLANAVERSION-jito

cd ~/jito-solana && git pull ; git checkout tags/$TAG && git submodule update --init --recursive && \
CI_COMMIT=$(git rev-parse HEAD) scripts/cargo-install-all.sh --validator-only ~/.local/share/solana/install/releases/"$TAG"

ln -nsf /root/.local/share/solana/install/releases/"$TAG" /root/.local/share/solana/install/active_release
