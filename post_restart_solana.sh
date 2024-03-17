#!/bin/bash
# set -x -e
# run by 
# wget -O /root/solana/post_restart_solana.sh https://raw.githubusercontent.com/Vahhhh/solana/main/post_restart_solana.sh && chmod +x /root/solana/post_restart_solana.sh
echo "###################### WARNING!!! ###################################"
echo "###   This script will perform the following operations:          ###"
echo "###   * inform you about restart                                  ###"
echo "###   * catchup this node                                         ###"
echo "###   * change the identity to staked if node is delinq           ###"
echo "###                                                               ###"
echo "###   *** Script provided by MARGUS.ONE and Vah StakeITeasy       ###"
echo "#####################################################################"
echo

NODE_NAME=""

SLEEP_SEC=30
service_file="/root/solana/solana.service"

LEDGER=$(grep '\--ledger ' $service_file | awk '{ print $2 }')        # path to ledger (default: /root/solana/ledger)
SNAPSHOTS=$(grep '\--snapshots ' $service_file | awk '{ print $2 }')  # path to snapshots (default: /root/solana/ledger)

ICON=`echo -e '\U0001F514'`
PATH="/root/.local/share/solana/install/active_release/bin:$PATH"

send_message() {
telegram_bot_token=""
telegram_chat_id=""
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
    solana catchup --our-localhost $rpcPort ; status=$?
    if [ $status -eq 0 ]
    then
      DELINQ=$(solana validators -um --output json-compact | jq -c --arg pub_key1 "$(solana address)" '.validators[] | select(.identityPubkey==$pub_key1 ) | .delinquent ')
        if [[ $DELINQ == false ]]
        then
          echo "Node is running on another server, don't touch identity"
        else
          solana-validator -l $LEDGER set-identity /root/solana/validator-keypair.json
        fi
      break
    fi
    echo "waiting next $SLEEP_SEC seconds for rpc"
    sleep $SLEEP_SEC
  done
}

send_message "${ICON} Solana alert! ${NODE_NAME}" "Solana service has been restarted! identity - $(ls -l /root/solana/identity.json | awk '{ print $NF }')"
send_message "${ICON} Solana alert! ${NODE_NAME}" "$(catchup_info)"

