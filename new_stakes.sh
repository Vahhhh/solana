#!/bin/bash
#set -x -e

BIN_PATH="$HOME/.local/share/solana/install/active_release/bin"
NODE_ID=(identity1 identity2)
API_URL=https://api.mainnet-beta.solana.com


send_message() {
telegram_bot_token=""               # enter your telegram bot token from botfather
telegram_chat_id=""                 # enter your telegram id or chat id
Title="$1"
Message="$2"
curl -s \
 --data parse_mode=HTML \
 --data chat_id=${telegram_chat_id} \
 --data text="<b>${Title}</b>%0A${Message}" \
 --request POST https://api.telegram.org/bot${telegram_bot_token}/sendMessage
}


ICON=`echo -e '\U0001F6E0'`
KEY_ICON=`echo -e '\U0001F511'`
VKEY_ICON=`echo -e '\U0001F5DD'`
EPOCH_ICON=`echo -e '\U0001F314'`
LAMP_ICON=`echo -e '\U0001F4A1'`
SLOTS_ICON=`echo -e '\U0001F4F8'`
SLOT_ICON=`echo -e '\U0001F4F7'`
TIME_ICON=`echo -e '\U0001F550'`
EL_ICON=`echo -e '\U0001F50C'`
I_ICON=`echo -e '\U0001F310'`
STAKE_ICON=`echo -e '\U0001F969'`
USDS_ICON=`echo -e '\U0001F4B0'`
PGR_ICON=`echo -e '\U0001F4CA'`
VHS_ICON=`echo -e '\U0001F4FC'`
DC_ICON=`echo -e '\U0001F5A5'`
OK_ICON=`echo -e '\U0001F7E2'`
YEL_ICON=`echo -e '\U0001F7E1'`
NOK_ICON=`echo -e '\U0001F534'`
DVD_ICON=`echo -e '\U0001F4C0'`
TOP_ICON=`echo -e '\U0001F51D'`
UP_ICON=`echo -e '\U0001F680'`
DOWN_ICON=`echo -e '\U0001F53B'`
V_ICON=`echo -e '\u267B'`
Q_ICON=`echo -e '\u2753'`
PLUS_ICON=`echo -e '\u2795'`
LINK_ICON=`echo -e '\U0001F517'`
EX_ICON=`echo -e '\u2757'`
USD_ICON=`echo -e '\U0001F4B2'`

JPOOL=HbJTxftxnXgpePCshA8FubsRj9MW4kfPscfuUfn44fnt
MARINADE_L=9eG63CdHjsfhHmobHgLtESGC8GabbmRcaSpHAZrtmhco
MARINADE_N=CyAH9f9awBcfuZqHzwwEs4uJBLEG33S743jxnQX1KcZ6
JITO=6iQKfEyhr3bZMotVkW6beNZz5CPAkiwvgV2CTje9pVSS
BLAZESTAKE=6WecYymEARvjG5ZyqkrVQ6YkhPfujNzWpSPwNKXHCbV2
SOLANAFNDN=4ZJhPQAgUseCsWhKvJLTmmRRUV74fdoTpQLNfKoekbPY
ALAMEDA=EhYXq3ANp5nAerUpbSgd7VK2RRcxK1zNuSQ755G5Mtxx


for index in ${!NODE_ID[*]}
do

RESPONSE_STAKES=$(solana stakes ${NODE_ID[$index]} --url ${API_URL} --output json-compact)

for AW in $JPOOL $MARINADE_L $MARINADE_N $JITO $BLAZESTAKE $SOLANAFNDN $ALAMEDA
do
   if [ $AW == "HbJTxftxnXgpePCshA8FubsRj9MW4kfPscfuUfn44fnt" ]; then POOL=JPOOL
   elif [ $AW == "9eG63CdHjsfhHmobHgLtESGC8GabbmRcaSpHAZrtmhco" ]; then POOL=MARINADE_L
   elif [ $AW == "CyAH9f9awBcfuZqHzwwEs4uJBLEG33S743jxnQX1KcZ6" ]; then POOL=MARINADE_N
   elif [ $AW == "6iQKfEyhr3bZMotVkW6beNZz5CPAkiwvgV2CTje9pVSS" ]; then POOL=JITO
   elif [ $AW == "6WecYymEARvjG5ZyqkrVQ6YkhPfujNzWpSPwNKXHCbV2" ]; then POOL=BLAZESTAKE
   elif [ $AW == "4ZJhPQAgUseCsWhKvJLTmmRRUV74fdoTpQLNfKoekbPY" ]; then POOL=SOLANAFNDN
   elif [ $AW == "EhYXq3ANp5nAerUpbSgd7VK2RRcxK1zNuSQ755G5Mtxx" ]; then POOL=ALAMEDA
   fi

   ACTIVE=$(echo "scale=2; $(echo $RESPONSE_STAKES | jq -c --arg AW "$AW" '[.[] | select(.withdrawer==$AW) | .activeStake] | add' | bc -l) /1000000000" | bc -l)
   ACTIVATING=$(echo "scale=2; $(echo $RESPONSE_STAKES | jq -c --arg AW "$AW" '[.[] | select(.withdrawer==$AW)| .activatingStake] | add' | bc -l)/1000000000" | bc -l)

   if (( $(echo "$ACTIVATING > 0" | bc -l) ));then
        ACT_STAKE_MSG="${UP_ICON} ${PLUS_ICON}<b>$ACTIVATING SOL</b> to ${NODE_ID[$index]} on ${HOSTNAME}"
    else
        ACT_STAKE_MSG="none"
   fi

   DEACTIVATING=$(echo "scale=2; $(echo $RESPONSE_STAKES | jq -c --arg AW "$AW" '[.[] | select(.withdrawer==$AW) | .deactivatingStake] | add' | bc -l)/1000000000" | bc -l)

   PUB=$(echo ${NODE_ID[$index]:0:10})

   if (( $(echo "$DEACTIVATING > 0" | bc -l) ));then
        if [ "$ACT_STAKE_MSG" = "none" ]; then
           ACT_STAKE_MSG="${DOWN_ICON} <b>-$DEACTIVATING SOL</b>"
           send_message "<b>$PUB - [Stakepool: $POOL]</b>" "${ACT_STAKE_MSG}" >> /dev/null
        else
           ACT_STAKE_MSG="${ACT_STAKE_MSG} | ${DOWN_ICON} <b>-$DEACTIVATING SOL</b> to stake"
           send_message "$PUB - <b>[Stakepool: $POOL]</b>" "${ACT_STAKE_MSG}" >> /dev/null
        fi
   else
       if [ "$ACT_STAKE_MSG" = "none" ]; then
            ACT_STAKE_MSG="${V_ICON} <i><b>No action taken</b></i>"
        else
            ACT_STAKE_MSG="${ACT_STAKE_MSG}"
            send_message "<b>$PUB - [Stakepool: $POOL]</b>" "${ACT_STAKE_MSG}" >> /dev/null
       fi
   fi
   echo -e $(date) >> /root/new-stakes.log  && echo "<b>$PUB - [Stakepool: $POOL]</b>" "${ACT_STAKE_MSG}" >> /root/new-stakes.log

done
done
