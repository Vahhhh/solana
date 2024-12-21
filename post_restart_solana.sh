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

networkrpcURL=$(cat /root/.config/solana/cli/config.yml | grep json_rpc_url | grep -o '".*"' | tr -d '"')
if [ "$networkrpcURL" == "" ]; then networkrpcURL=$(cat /root/.config/solana/cli/config.yml | grep json_rpc_url | awk '{ print $2 }')
fi
if [ "$networkrpcURL" == "https://api.testnet.solana.com" ]; then network=t
fi
if [ "$networkrpcURL" == "https://api.mainnet-beta.solana.com" ]; then network=m
fi

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
    rpcPort=$(ps aux | grep agave-validator | grep -Po "\-\-rpc\-port\s+\K[0-9]+")
    solana catchup --our-localhost $rpcPort ; status=$?
    if [ $status -eq 0 ]
    then
      DELINQ=$(solana validators -u$network --output json-compact | jq -c --arg pub_key1 "$(solana address)" '.validators[] | select(.identityPubkey==$pub_key1 ) | .delinquent ')
        if [[ $DELINQ == false ]]
        then
          echo "Node is running on another server, don't touch identity"
        else
          agave-validator -l $LEDGER set-identity /root/solana/validator-keypair.json
        fi
      break
    fi
    echo "waiting next $SLEEP_SEC seconds for rpc"
    sleep $SLEEP_SEC
  done
}

sed -i '/monitor.sh/s/^#*/#/g' -i_backup /etc/crontab  # (to comment out)

send_message "${ICON} Solana alert! $HOSTNAME - ${NODE_NAME} - $0" "Solana service has been restarted! identity - $(solana address -k /root/solana/identity.json)"
send_message "${ICON} Solana alert! $HOSTNAME - ${NODE_NAME} - $0" "$(catchup_info)"

sed -i '/monitor.sh/s/^#*//g' -i_backup /etc/crontab  # (to uncomment)
