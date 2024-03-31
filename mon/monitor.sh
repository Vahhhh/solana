#!/bin/bash
#set -e -x
# input vars
LOCK_FILE=/root/mon/catchup.lock
KEY_NAME="validator-keypair.json"
TIMEOUT=30
SLEEP_SEC=30

# calc vars
SCRIPT_DIR=`cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P`
APP_SOLANA="/root/.local/share/solana/install/releases/forge/bin/solana"
APP_SOLANA_VALIDATOR="/root/.local/share/solana/install/releases/forge/bin/solana-validator"
KEYS_PATH="/root/solana/validator-keypair.json"
ID_PUBKEY=`${APP_SOLANA} address -k ${KEYS_PATH}`

SCRIPT_DIR=`cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P`

# backup node IP-address or hostname
node2=69.10.34.154

#telegram info from other scripts

ICON=`echo -e '\U0001F514'`

send_message() {
# Please, add these  to ~/.profile or uncomment the following lines
#telegram_bot_token="XXXXXXXXXX:XXXXXXXXXXXXXXXXXXXXXXX"
#telegram_chat_id="XXXXXXXXXXXXXXXXX"
Title="$1"
Message="$2"
curl -s \
 --data parse_mode=HTML \
 --data chat_id=${telegram_chat_id} \
 --data text="<b>${Title}</b>%0A${Message}" \
 --request POST https://api.telegram.org/bot${telegram_bot_token}/sendMessage
}

catchup_info() {
  while true; do
    rpcPort=$(ps aux | grep solana-validator | grep -Po "\-\-rpc\-port\s+\K[0-9]+")
    ${APP_SOLANA} catchup --our-localhost $rpcPort ; status=$?
    if [ $status -eq 0 ]
    then
      DELINQ=$(${APP_SOLANA} validators -um --output json-compact | jq -c --arg pub_key1 "${ID_PUBKEY}" '.validators[] | select(.identityPubkey==$pub_key1 ) | .delinquent ')
        if [[ $DELINQ == false ]]
        then
          echo "Node is running on another server, don't touch identity"
        else
          ${APP_SOLANA_VALIDATOR} --ledger $(grep '\--ledger ' /root/solana/solana.service | awk '{ print $2 }') set-identity /root/solana/validator-keypair.json
        fi
      break
    fi
    echo "waiting next $SLEEP_SEC seconds for rpc"
    sleep $SLEEP_SEC
  done
}

PING_1=$(ping -c 4 8.8.8.8 | grep transmitted | awk '{print $4}')
if [[ $PING_1 == 0 ]]; then sleep 5
PING_1=$(ping -c 4 8.8.8.8 | grep transmitted | awk '{print $4}')
fi
PING_2=$(ping -c 4 1.1.1.1 | grep transmitted | awk '{print $4}')
if [[ $PING_2 == 0 ]]; then sleep 5
PING_2=$(ping -c 4 1.1.1.1 | grep transmitted | awk '{print $4}')
fi
PING_NODE2=$(ping -c 4 $node2 | grep transmitted | awk '{print $4}')
if [[ $PING_NODE2 == 0 ]]; then sleep 10
PING_NODE2=$(ping -c 4 $node2 | grep transmitted | awk '{print $4}')
fi

INSYNC_FULL=`timeout ${TIMEOUT} ${APP_SOLANA} catchup --our-localhost`
INSYNC=`echo $INSYNC_FULL | grep caught`
ID_INSYNC=`echo $INSYNC_FULL | awk '{print $1}'`

if [[ $PING_1 == 0 ]] && [[ $PING_2 == 0 ]]
then
   $APP_SOLANA_VALIDATOR --ledger $(grep '\--ledger ' /root/solana/solana.service | awk '{ print $2 }') set-identity /root/solana/unstaked-identity.json
# set unstaked identity
fi


if [ -f "$LOCK_FILE" ]; then
echo $LOCK_FILE exists
exit 1
fi


if [[ $PING_NODE2 == 0 ]]
then
        echo "`date` ALARM! 2nd node doesn't PING"
        touch $LOCK_FILE
        send_message "${ICON} Solana alert! $HOSTNAME - ${NODE_NAME} - $0" "ALARM! 2nd node doesn't ping"
        send_message "${ICON} Solana alert! $HOSTNAME - ${NODE_NAME} - $0" "$(catchup_info)"
        rm -rf $LOCK_FILE
        exit 11
fi

if [[ -z ${INSYNC_FULL} ]]
then
        echo "`date` ALARM! node is out of sync"
        touch $LOCK_FILE
        send_message "${ICON} Solana alert! $HOSTNAME - ${NODE_NAME} - $0" "ALARM! node is out of sync, trying to sync"
        send_message "${ICON} Solana alert! $HOSTNAME - ${NODE_NAME} - $0" "$(catchup_info)"
        rm -rf $LOCK_FILE
        exit 12
fi

IS_DELINQUENT=`timeout ${TIMEOUT} ${APP_SOLANA} validators --output json | jq -r ".validators[] | select(.identityPubkey==\"${ID_PUBKEY}\") | .delinquent"`
#echo $IS_DELINQUENT

if [[ ${IS_DELINQUENT} == "true" ]]|| [[ -z ${IS_DELINQUENT} ]]
then
        touch $LOCK_FILE
        echo "`date` ALARM! node is delinquent"
        send_message "${ICON} Solana alert! $HOSTNAME - ${NODE_NAME} - $0" "ALARM! node is delinq, cheching sync and setting STAKED identity"
        send_message "${ICON} Solana alert! $HOSTNAME - ${NODE_NAME} - $0" "$(catchup_info)"
        rm -rf $LOCK_FILE
        exit 13
# to be commented :)
else
    echo "`date` node is not delinq"
fi
