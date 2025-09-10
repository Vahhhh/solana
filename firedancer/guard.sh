#!/bin/bash
GUARD_VER=v1.8.24
#=================== guard.cfg ========================
PORT='22' # remote server ssh port
#KEYS=$HOME/keys
KEYS=/mnt/keys
LOG_FILE=$HOME/solana-guard/guard.log
GUARD_CFG=$HOME/solana-guard/guard.cfg
SOLANA_SERVICE="$HOME/solana/solana_agave.service"
BEHIND_WARNING=false # 'false'- send telegramm INFO missage, when behind. 'true'-send ALERT message
WARNING_FREQUENCY=12 # max frequency of warning messages (WARNING_FREQUENCY x 5) seconds
BEHIND_OK_VAL=1 # behind, that seemed ordinary
RELAYER_SERVICE=false # "false" - disable relayer service
configDir="$HOME/.config/solana"
FD_BIN="/root/firedancer/build/native/gcc/bin/fdctl"
# CHAT_ALARM=-1001..5684
# CHAT_INFO=-1001..2888
# BOT_TOKEN=50762..CllWU
# alternative RPC URL list
# RPC_LIST=(
# "https://mainnet.helius-rpc.com..."
# "https://mainnet.helius-rpc.com..."
# )
#======================================================
if [ -f "$GUARD_CFG" ]; then
    source "$GUARD_CFG" # get settings
    KEYS=$(echo "$KEYS" | tr -d '\r') # Удаление символа \r, если он есть
    SOLANA_SERVICE=$(echo "$SOLANA_SERVICE" | tr -d '\r') # Remove \r character if exists
        configDir=$(echo "$configDir" | tr -d '\r') # Remove \r character if exists
        BOT_TOKEN=$(echo "$BOT_TOKEN" | tr -d '\r') # Remove \r character if exists
else
        echo "Error: $GUARD_CFG does not exist, set default settings" >&2
fi
LEDGER=$(grep -oP '(?<=--ledger\s).*' "$SOLANA_SERVICE" | tr -d '\\\r\n' | xargs)
EMPTY_KEY=$(grep -oP '(?<=--identity\s).*' "$SOLANA_SERVICE" | tr -d '\\\r\n' | xargs)
VOTING_KEY=$(grep -oP '(?<=--authorized-voter\s).*' "$SOLANA_SERVICE" | tr -d '\\\r\n' | xargs)
IDENTITY=$(solana address 2>/dev/null)
if [ $? -ne 0 ]; then
        echo "Error! Can't run 'solana'"
        return
fi
# Extract RPC port and setup local RPC URL
RPC_PORT=$(grep -oP '(?<=--rpc-port\s).*' "$SOLANA_SERVICE" | tr -d '\\\r\n' | xargs)
if [[ -z "$RPC_PORT" ]]; then
    LOCAL_RPC="" # No local RPC port found in solana.service, using public RPC
else
    LOCAL_RPC="http://localhost:$RPC_PORT" # Using local RPC for leader schedule and epoch info queries
fi
VOTING_ADDR=$(solana address -k $VOTING_KEY)
EMPTY_ADDR=$(solana address -k $EMPTY_KEY)
rpcURL1=$(solana config get | grep "RPC URL" | awk '{print $3}')
version=$(agave-validator --version 2>/dev/null)
if [ $? -ne 0 ]; then
    echo "Error! Can't run 'agave-validator'"
        return
else
        version=$(echo "$version" | awk -F '[ ()]' '{print $1, $2, $NF}' | sed 's/client://')
fi
client=$(solana --version | awk -F'client:' '{print $2}' | tr -d ')')
CUR_IP=$(wget -q -4 -O- http://icanhazip.com)
SITES=("8.8.8.8" "1.1.1.1")  # Google Public DNS & Cloudflare DNS to ping
SOL_BIN="$(cat ${configDir}/install/config.yml | grep 'active_release_dir\:' | awk '{print $2}')/bin"
GRAY=$'\033[90m'; GREEN=$'\033[32m'; RED=$'\033[31m'; YELLOW=$'\033[33m'; BLUE=$'\033[34m'; CLEAR=$'\033[0m'
# ======================
if [[ -f $LOG_FILE ]]; then
    rpc_index=$(grep -oP 'rpc_index=\K\d+' "$LOG_FILE" | tail -n 1) # Read last rpc_index from log file
fi
if [[ -z "$RPC_LIST" ]]; then
    RPC_LIST=($rpcURL1) # Add RPC server to array to avoid errors
        rpc_index=0
        echo -e "Warning! $RED RPC_LIST is not defined in $GUARD_CFG ! $CLEAR"
fi
if [[ -z "$BOT_TOKEN" ]]; then
        echo -e "Warning! $RED Telegram BOT_TOKEN is not defined in $GUARD_CFG ! $CLEAR"
fi
# agave-validator -l /root/solana/ledger/ contact-info
if ! command -v bc &> /dev/null; then
    echo "Warning! 'bc' not installed. Please run 'apt install bc'"
    return
fi
# Check and setup RELAYER_SERVICE
if [[ "$RELAYER_SERVICE" == "false" || -z "$RELAYER_SERVICE" ]]; then
    RELAYER_SERVICE=""
elif [[ "$RELAYER_SERVICE" == "true" ]]; then # for compatibility with the old cfg file
    RELAYER_SERVICE="relayer.service"
fi


TIME() {
        TZ=Europe/Moscow date +"%b %e  %H:%M:%S"
        }
LOG() {
    local message="$1"
    echo "$(TIME) $message" | tee -a $LOG_FILE  #
        }
SEND_INFO(){
        local message="$1"
        curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" -d chat_id=$CHAT_INFO -d text="$message" > /dev/null
        echo "$(TIME) $message" >> $LOG_FILE
        echo -e "$(TIME) $GREEN $message $CLEAR"
        }
SEND_ALARM(){
        local message="$1"
        curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" -d chat_id=$CHAT_ALARM -d text="$message" > /dev/null
        echo "$(TIME) $message" >> $LOG_FILE
        echo -e "$(TIME) $RED $message $CLEAR"
        }

REQUEST_IP(){
        #sleep 0.5
        local RPC_URL="$1"
        VALIDATOR_REQUEST=$(timeout 9 solana gossip --url $RPC_URL 2>> $LOG_FILE)
        if [ $? -ne 0 ]; then
                echo "$(TIME) Error in REQUEST_IP for RPC $RPC_URL" >> $LOG_FILE
        fi
        if [ -z "$VALIDATOR_REQUEST" ]; then
                echo "$(TIME) Error in REQUEST_IP: validator request emty" >> $LOG_FILE
        fi
        echo "$VALIDATOR_REQUEST" | grep "$IDENTITY" | awk '{print $1}'
        }

REQUEST_DELINK(){
        #sleep 0.5
        local RPC_URL="$1"
        VALIDATORS_LIST=$(timeout 9 solana validators --url $RPC_URL --output json 2>> $LOG_FILE)
        if [ $? -ne 0 ]; then
                echo "$(TIME) Error in REQUEST_DELINK for RPC $RPC_URL" >> $LOG_FILE
        fi
        if [ -z "$VALIDATORS_LIST" ]; then
                echo "$(TIME) Error in REQUEST_DELINK: validators list empty" >> $LOG_FILE
        fi
        JSON=$(echo "$VALIDATORS_LIST" | jq '.validators[] | select(.identityPubkey == "'"${IDENTITY}"'" )')
        LastVote=$(echo "$JSON" | jq -r '.lastVote')
        echo "$JSON" | jq -r '.delinquent'
        }

REQUEST_ANSWER=""
Wrong_request_count=0
RPC_REQUEST() {
    local REQUEST_TYPE="$1"
    local REQUEST1 REQUEST2


    if [[ "$REQUEST_TYPE" == "IP" ]]; then
                FUNCTION_NAME="REQUEST_IP"
        elif [[ "$REQUEST_TYPE" == "DELINK" ]]; then
        FUNCTION_NAME="REQUEST_DELINK"
        else
                REQUEST_ANSWER=""; return
    fi
        # 1. ОДИН запрос к основному RPC
        REQUEST1=$(eval "$FUNCTION_NAME \"$rpcURL1\"")

    # Проверка на ошибку или пустой ответ
    if [[ -n "$REQUEST1" && "$REQUEST1" != "NULL" ]]; then
        REQUEST_ANSWER="$REQUEST1"
        Wrong_request_count=0
        return
    fi
        # 2. Если ошибка или пусто — перепроверяем
        rpcURL2="${RPC_LIST[$rpc_index]}" # Получаем текущий RPC URL из списка
        REQUEST1=$(eval "$FUNCTION_NAME \"$rpcURL1\"") # запрос к РПЦ соланы
        REQUEST2=$(eval "$FUNCTION_NAME \"$rpcURL2\"") # запрос к одному из РПЦ хелиуса из списка RPC_LIST

        # Сравнение результатов
    if [[ "$REQUEST1" == "$REQUEST2" ]]; then
        REQUEST_ANSWER="$REQUEST1";
                Wrong_request_count=0
                return
    fi
                #echo "$(TIME) Warning! Different answers: RPC1=$REQUEST1, RPC2=$REQUEST2" >> $LOG_FILE
                # Если результаты разные, опрашиваем в цикле 10 раз
        declare -A request_count
        RQST1_counter=0; RQST2_counter=0
        for i in {1..10}; do
                RQST1=$(eval "$FUNCTION_NAME \"$rpcURL1\"") # Вызов функции через eval
                RQST2=$(eval "$FUNCTION_NAME \"$rpcURL2\"")

                if [[ -z "$RQST1" ]]; then
                        RQST1="NULL" # Чтобы не пихать в массив пустые значения, пропишем 'NULL'
                else
                        ((request_count["$RQST1"]++)) # Увеличиваем счётчики для непустых значений
                        ((RQST1_counter++))
                fi

                if [[ -z "$RQST2" ]]; then
                        RQST2="NULL"
                else
                        ((request_count["$RQST2"]++)) # Увеличиваем счётчики для непустых значений
                        ((RQST2_counter++))
                fi
                echo "$(TIME) RPC1='$RQST1', RPC2='$RQST2'" >> $LOG_FILE
        done

        if [[ $RQST2_counter -eq 0 ]]; then # резервный РПЦ молчит, скорее всего кончился лимит бесплатного аккаунта Helius.
        ((rpc_index++)) # Увеличиваем индекс, т.е. переключимся на следующий RPC сервер из списка.
                if [[ $rpc_index -ge ${#RPC_LIST[@]} ]]; then rpc_index=0; fi # проверяем, не вышли ли мы за пределы списка РПЦ серверов
                LOG "Change Helius rpc_index=$rpc_index"
        fi



        # Находим наиболее частый ответ
        most_frequent_answer=""
        max_count=0
        RQST_counter=$((RQST1_counter + RQST2_counter))

        for answer in "${!request_count[@]}"; do
                if (( request_count["$answer"] > max_count )); then
                        max_count=${request_count["$answer"]}
                        most_frequent_answer=$answer
                fi
        done

        if [[ -z "$most_frequent_answer" || "$most_frequent_answer" == "NULL" || $RQST_counter -lt 5 ]]; then
                REQUEST_ANSWER=""
                LOG "Warnign! most_frequent_answer='$most_frequent_answer', RPC.1 requests=$RQST_counter, RPC.2 requests=$RQST2_counter"
                return
        else
                percentage=$(( (max_count * 100) / RQST_counter ))
                # LOG "Requests=$RQST_counter percentage=$percentage"
        fi

        if [[ $percentage -lt 70 ]]; then # не принимаем ответ, если он встречается в менее 70% запросов
                ((Wrong_request_count++))
                if [[ $Wrong_request_count -ge 3 ]]; then # дохрена ошибок запросов RPC
            SEND_ALARM "$SERV_TYPE ${NODE}.${NAME} RPC.sol='$REQUEST1'/$RQST1_counter, RPC.$rpc_index='$REQUEST2'/$RQST2_counter, differ$percentage%"
            Wrong_request_count=0  # Сбрасываем счетчик после предупреждения
        fi
                LOG "Error! Empty answer: RPC.sol='$REQUEST1'/$RQST1_counter, RPC.$rpc_index='$REQUEST2'/$RQST2_counter, dominate[$percentage%]='$most_frequent_answer'"
                REQUEST_ANSWER="";
        else
                REQUEST_ANSWER="$most_frequent_answer"
                Wrong_request_count=0
                LOG "Warning! Different answers: RPC.sol='$REQUEST1'/$RQST1_counter, RPC.$rpc_index='$REQUEST2'/$RQST2_counter, dominate[$percentage%]='$most_frequent_answer'"
        fi

        # echo "$(TIME) REQUEST_ANSWER: $REQUEST_ANSWER" >>  $LOG_FILE
        }

DDOS_MONITOR() { # check nftables log for DDOS warnings
    line=$(tail -n 1 /var/log/kern.log | grep "NFT")
    attack_type=$(echo "$line" | grep -oE '\[NFT\] [A-Z-]+' | cut -d' ' -f2)
    ip=$(echo "$line" | grep -oP 'SRC=\K[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
    port=$(echo "$line" | grep -oP 'DPT=\K[0-9]+')
    message="Detected: $attack_type from: $ip to: $port"
    if [ -z "$last_message" ]; then
        last_message="$message"
    fi

    if [ "$message" != "$last_message" ]; then
        SEND_ALARM "$SERV_TYPE ${NODE}.${NAME}: $message"
        last_message=$message
    fi
}

GET_VOTING_IP(){
    # get voiting validator IP
        RPC_REQUEST "IP"
        if [ -z "$REQUEST_ANSWER" ]; then
                LOG "Error in GET_VOTING_IP: VOTING_IP empty, keep previous value"
                return 1
        fi
        VOTING_IP=$REQUEST_ANSWER
    SERV="$USER@$VOTING_IP"
    # get local validator addr
    contact_info=$(agave-validator --ledger "$LEDGER" contact-info)
        if [ $? -ne 0 ]; then
            LOG "Error: $contact_info"
            local_validator=""
        else
            local_validator=$(echo "$contact_info" | grep "Identity:" | awk '{print $2}')
        fi
    # IP compare to set server type
    if [[ "$CUR_IP" == "$VOTING_IP" && "$local_validator" == "$IDENTITY" ]]; then
        SERV_TYPE='PRIMARY'
    elif [[ "$local_validator" == "$EMPTY_ADDR" ]]; then
        SERV_TYPE='SECONDARY'
        else
                SERV_TYPE='UNDEFINED'
                LOG "Warning! SERV_TYPE='UNDEFINED'.
                CUR_IP=$CUR_IP, VOTING_IP=$VOTING_IP,
                local_validator=$local_validator,
                IDENTITY=$IDENTITY,
                EMPTY_ADDR=$EMPTY_ADDR"
    fi
        }



SSH_OPTS=(
    "-o ControlMaster=auto"             # Reuse a single master connection
    "-o ControlPath ~/.ssh/cm/%r@%h:%p" # Short, hashed socket path (%C = per-conn hash)
    "-o ControlPersist=300"             # Keep master connection for 5 minutes
    "-o ConnectTimeout=5"               # Limit TCP connect time
        #"-o BatchMode=yes"                 # Non-interactive fast-fail
    "-o ServerAliveInterval=30"         # Send keepalive every 30s
    "-o ServerAliveCountMax=3"          # Drop after 3 missed keepalives
    "-o LogLevel=ERROR"                 # Quieter logs
)
command_exit_status=0; command_output=''; ssh_alarm_time=0 # set global variable
SSH(){
        local ssh_command="$1"
        local err_file="/tmp/ssh_error.tmp"
        trap 'rm -f "$err_file"' EXIT

        command_output=$(timeout 5 ssh "${SSH_OPTS[@]}" REMOTE $ssh_command 2>$err_file)
        command_exit_status=$?
        # timeout - ограничивает общее время выполнения ssh-команды (попытка соединения + выполнение команды)
        # ConnectTimeout - допустимое время на установления TCP-соединения
        # -vvv - расширенный отладочный вывод

        # SSH errors
        if [ $command_exit_status -ne 0 ]; then
        case $command_exit_status in
                        255)  # standart SSH errors
                                LOG "SSH Error: $(cat $err_file)"
                                ;;
                        130)  # Ctrl+C
                                LOG "SSH Error: Connection interrupted"
                                ;;
                        137)  # SIGKILL
                                LOG "SSH Error: Connection killed"
                                ;;
                        143)  # SIGTERM
                                LOG "SSH Error: Connection terminated"
                                ;;
                        124)  # timeout
                                LOG "SSH Error: Connection timeout"
                                ;;
                        1)    # Общие ошибки выполнения
                                LOG "SSH Error: General error"
                                ;;
                5)    # I/O error или ошибка сети
                LOG "SSH Error: I/O or network error"
                ;;
            6)    # Ошибка разрешения имени хоста
                LOG "SSH Error: Host name resolution error"
                ;;
            7)    # Ошибка протокола
                LOG "SSH Error: Protocol error"
                ;;
                        *)
                                LOG "SSH Error: Command failed with exit code $command_exit_status"
                                ;;
                esac
                LOG "SSH Error: command_output=$command_output"
        if ping -c 3 -W 1 "$REMOTE_IP" > /dev/null 2>&1; then
                        LOG "remote server $REMOTE_IP ping OK"
                else
                        LOG "Error: remote server $REMOTE_IP did not ping"
                        if ping -c 3 -W 1 "8.8.8.8" > /dev/null 2>&1; then
                                LOG "Google ping OK"
                        else
                                LOG "Error: Google did not ping too"
                        fi
                fi
                if [ $((current_time - ssh_alarm_time)) -ge 120 ]; then
                SEND_ALARM "$SERV_TYPE ${NODE}.${NAME}: SSH Error $(cat $err_file)"
                ssh_alarm_time=$current_time
        fi
        fi
        }

health_counter=0
behind_counter=0
remote_behind_counter=0
slots_remaining=0
disconnect_counter=0
CHECK_HEALTH() { # self check health every 5 seconds  ###########################################
        DDOS_MONITOR # check nftables log for DDOS warnings
        # check behind slots
        Request_OK='true'
        RPC_SLOT=$(timeout 5 solana slot -u $rpcURL1 2>> $LOG_FILE)
        if [[ -z "$RPC_SLOT" ]]; then
                echo "$(TIME) RPC_SLOT request empty from $rpcURL1, try from $rpcURL2" >> $LOG_FILE
        RPC_SLOT=$(timeout 5 solana slot -u "$rpcURL2" 2>> "$LOG_FILE")
        fi
        if [[ $? -ne 0 ]]; then
                Request_OK='false';
                echo "$(TIME) Error in solana slot RPC request" >> $LOG_FILE
        fi
        LOCAL_SLOT=$(timeout 5 solana slot -u localhost 2>> $LOG_FILE)
        if [[ $? -ne 0 ]]; then
                Request_OK='false';
                LOG "Error in solana slot localhost request"
        fi
        if [[ $Request_OK == 'true' && -n "$RPC_SLOT" && -n "$LOCAL_SLOT" ]]; then
                BEHIND=$((RPC_SLOT - LOCAL_SLOT));
        else
                BEHIND=555;
        fi
        # sleep 1
        # epoch info
        EPOCH_INFO=$(timeout 5 solana epoch-info --output json --url $LOCAL_RPC 2>> $LOG_FILE)
        if [[ $? -ne 0 ]]; then
        echo "$(TIME) Error retrieving epoch info: $EPOCH_INFO" >> $LOG_FILE
                SLOTS_UNTIL_EPOCH_END=0
        else
                SLOTS_IN_EPOCH=$(echo "$EPOCH_INFO" | jq '.slotsInEpoch')
                SLOT_INDEX=$(echo "$EPOCH_INFO" | jq '.slotIndex')
                SLOTS_UNTIL_EPOCH_END=$(echo "$SLOTS_IN_EPOCH - $SLOT_INDEX" | bc)
        fi
        # next slot time
        output=$(timeout 5 solana leader-schedule -v --url $LOCAL_RPC 2>> $LOG_FILE)
        if [[ $? -ne 0 ]]; then
                echo "$(TIME) Error in leader schedule request" >> $LOG_FILE
                Request_OK='false';
        else
                my_slot=$(echo "$output" | grep "$IDENTITY" | awk -v var="$RPC_SLOT" '$1 >= var' | head -n1 | cut -d ' ' -f3)
                if [[ $? -ne 0 ]]; then
                        echo "$(TIME) Error processing leader schedule request output" >> $LOG_FILE
                        Request_OK='false';
                fi
        fi
        if [[ $Request_OK == 'true' && "$my_slot" =~ ^-?[0-9]+$ && "$RPC_SLOT" =~ ^-?[0-9]+$ ]]; then  #
        slots_remaining=$((my_slot - RPC_SLOT))
                NEXT_CLR=$BLUE
        elif [[ "$SLOTS_UNTIL_EPOCH_END" =~ ^-?[0-9]+$ ]]; then # переменная является числом
        slots_remaining=$SLOTS_UNTIL_EPOCH_END
                NEXT_CLR=$YELLOW
        else
        slots_remaining=0
        fi
        next_slot_time=$((($slots_remaining * 459) / 60000))
        if [[ $next_slot_time -lt 2 ]]; then NEXT_CLR=$RED; fi

        # check health
        REQUEST=$(curl -s -m 5 http://localhost:8899/health)
        if [ $? -ne 0 ]; then
                HEALTH="RequestError!"
                LOG "Error, health request=$REQUEST "
        else
                HEALTH=$REQUEST;
        fi
        if [[ -z $HEALTH ]]; then # if $HEALTH is empty (must be 'ok')
                HEALTH="Warning!"
        fi

        if [[ $health_counter -eq 0 && $behind_counter -eq 0 ]]; then # check 'health' & 'behind' from last requests
                CHECK_UP='true' # 'health' and 'behind' must be fine twice: last and current requests
        else
                CHECK_UP='false'
        fi
        if [[ $HEALTH == "ok" ]]; then
                health_counter=0
                HEALTH_PRN="$GREEN$HEALTH"
        else
                CHECK_UP='false'
                HEALTH_PRN="$RED$HEALTH"
                let health_counter=health_counter+1
                LOG "Health=$HEALTH, health_counter=$health_counter, CHECK_UP=$CHECK_UP    "  # log every warning_message
                if [[ $health_counter -ge 1 && $HEALTH != "behind" ]]; then #
                        health_counter=-$WARNING_FREQUENCY
                        SEND_ALARM "$SERV_TYPE ${NODE}.${NAME}: Health: $HEALTH"
                fi
        fi

        # check behind
        if [[ $BEHIND -le $BEHIND_OK_VAL ]]; then #  && $BEHIND -gt -1000  проверка на "число" и -1000<BEHIND<1
                behind_counter=0
                BEHIND_PRN="$GREEN$BEHIND"
        else
                CHECK_UP='false'
                let behind_counter=behind_counter+1
                LOG "Behind=$BEHIND    "  # log every warning_message
                BEHIND_PRN="$RED$BEHIND"
                if [[ $behind_counter -ge 3 ]] && [[ $BEHIND -ge $BEHIND_OK_VAL ]]; then #
                        behind_counter=-$WARNING_FREQUENCY # sent next message after  12*5 seconds
                        if [[ $BEHIND_WARNING == 'true' ]]; then SEND_ALARM "$SERV_TYPE ${NODE}.${NAME}: Behind=$BEHIND";
                        else SEND_INFO "$SERV_TYPE ${NODE}.${NAME}: Behind=$BEHIND"; fi
                fi
        fi
        REMOTE_BEHIND=$(cat $HOME/solana-guard/remote_behind)
        if [[ $REMOTE_BEHIND -le $BEHIND_OK_VAL ]]; then #  && $REMOTE_BEHIND -gt -1000 Check if number is valid and within range -1000<REMOTE_BEHIND<1
                remote_behind_counter=0
                REMOTE_BEHIND_PRN="$GREEN$REMOTE_BEHIND"
        else
        let remote_behind_counter=remote_behind_counter+1
                REMOTE_BEHIND_PRN="$RED$REMOTE_BEHIND";
        fi
        if [[ $CHECK_UP == 'true' ]]; then CHECK_PRN="$GREEN OK$CLEAR"; else CHECK_PRN="$RED warn$CLEAR"; fi
        echo -ne "$(TZ=Europe/Moscow date +"%H:%M:%S")  $SERV_TYPE ${NODE}.${NAME}, next:$NEXT_CLR$next_slot_time$CLEAR, behind:$BEHIND_PRN$CLEAR,$REMOTE_BEHIND_PRN$CLEAR, health $HEALTH_PRN$CLEAR, check$CHECK_PRN $YELLOW$primary_mode$CLEAR      \r"

        # check guard running on remote server
        current_time=$(date +%s)
        SSH "echo '$BEHIND' > $HOME/solana-guard/remote_behind"
        last_modified=$(date -r "$HOME/solana-guard/remote_behind" +%s)
        time_diff=$((current_time - last_modified)) #; echo "last: $time_diff seconds"
        if [ $time_diff -ge 300 ] && [ $((current_time - connection_alarm_time)) -ge 120  ]; then
                SEND_ALARM "guard inactive on ${NODE}.${NAME}, $REMOTE_IP"
                connection_alarm_time=$current_time
        fi
        }


CHECK_CONNECTION() { # self check connection every 5 seconds ####################################
    connection=false
    for site in "${SITES[@]}"; do
        ping -c1 $site &> /dev/null # ping every site once
        if [ $? -eq 0 ]; then
            connection=true # good connection
            break
        fi
    done
    # connection losses counter
    if [ "$connection" = false ]; then
        let disconnect_counter=disconnect_counter+1
        LOG "connection failed, attempt $disconnect_counter"
    else
        disconnect_counter=0
    fi
    # connection loss for 15 seconds (5sec * 3)
    if [ $disconnect_counter -ge 3 ]; then
        # bash "$CONNECTION_LOSS_SCRIPT" # no need to vote_off in offline
        systemctl restart solana
        SEND_ALARM "$SERV_TYPE ${NODE}.${NAME}: Connection loss, RESTART SOLANA"
        fi
  }

COPY_TOWER(){ # copy tower file from PRIMARY to SECONDARY
    timeout 2 ssh "${SSH_OPTS[@]}" REMOTE "cat $LEDGER/tower-1_9-$IDENTITY.bin" > "$LEDGER/tower-1_9-$IDENTITY.bin"
    return $?
}


RELAYER_ERRORS="block engine failed: aoi updates disconnected"
relayer_alarm_time=0
CHECK_RELAYER(){ # check relayer service on current server
        if [[ -n "$RELAYER_SERVICE" && $((current_time - relayer_alarm_time)) -ge 120 ]]; then
                if systemctl is-active --quiet "$RELAYER_SERVICE"; then
                MATCHES=$(journalctl -u "$RELAYER_SERVICE" --since "3 seconds ago" | grep -E "$RELAYER_ERRORS")
                        if [[ -n "$MATCHES" ]]; then
                                echo "$(TIME) $MATCHES" >> $LOG_FILE
                        SEND_ALARM "$SERV_TYPE ${NODE}.${NAME}: relayer Error"
                                relayer_alarm_time=$current_time
                        fi
                else
                        SEND_ALARM "$SERV_TYPE ${NODE}.${NAME}: Relayer inactive! try to restart it"
                        ln -sf ~/solana/$RELAYER_SERVICE /etc/systemd/system
                        systemctl restart "$RELAYER_SERVICE"
                        relayer_alarm_time=$current_time
                        if [[ $? -eq 0 ]]; then
                                LOG "Relayer restarted successfully"
                        else
                                LOG "Error: Relayer restart failed"
                        fi
                fi
        fi
        }

CREDITS_GAP(){ # get credits difference between my validator and TVC leader
        response=$(curl -s -X POST "$LOCAL_RPC" \
            -H "Content-Type: application/json" \
            -d "{
                \"jsonrpc\": \"2.0\",
                \"id\": 1,
                \"method\": \"getVoteAccounts\",
                \"params\": [{\"commitment\": \"finalized\"}]
            }")

        my_credits=$(echo "$response" | jq -r "
            .result.current[] |
            select(.votePubkey == \"$vote_account\") |
            .epochCredits[-1][1] // 0")

        max_credits=$(echo "$response" | jq -r "
            [.result.current[].epochCredits[-1][1]] | max // 0")

        echo $(( max_credits - my_credits ))
        }

PRIMARY_SERVER(){ #######################################################################
        #echo -e "\n = PRIMARY  SERVER ="
        SEND_INFO "PRIMARY ${NODE}.${NAME} $CUR_IP start"
        while [ "$SERV_TYPE" = "PRIMARY" ]; do
                CHECK_CONNECTION
                CHECK_HEALTH
                GET_VOTING_IP
                CHECK_RELAYER
                sleep 3
        done
        LOG "PRIMARY status ended"
        sleep 20
        }

SECONDARY_SERVER(){ ##################################################################
        SEND_INFO "SECONDARY ${NODE}.${NAME} $CUR_IP start"
        if [[ -n "$RELAYER_SERVICE" ]] && systemctl is-active --quiet "$RELAYER_SERVICE"; then
                LOG  "Relayer is active! try to stop it"
                systemctl stop "$RELAYER_SERVICE"
                if [[ $? -eq 0 ]]; then
                        LOG "Relayer stoped successfully"
                else
                        LOG "Error: Relayer stop failed"
                fi
        fi
        # waiting remote server fail and selfcheck health
        set_primary=0 #
        REASON=''
        until [[ $CHECK_UP == 'true' && $set_primary -ge 1 ]]; do #
                RPC_REQUEST "DELINK"
                Delinquent=$REQUEST_ANSWER
                if [[ $Delinquent == true ]]; then
                        set_primary=2;  REASON="Delinquent"; LOG "Warning!$RED Delinquent detected! $CLEAR"
                fi
                if [[ $behind_threshold -ge 1 ]] && [[ $remote_behind_counter -ge $behind_threshold ]]; then
                        set_primary=2;  REASON="Behind too long"; LOG "Warning! Behind detected! "
                fi
                if [[ $primary_mode == "permanent_primary" && next_slot_time -ge 1 ]]; then
                        set_primary=2;  REASON="set Permanent Primary mode";
                fi
                CHECK_HEALTH #  self check node health
                GET_VOTING_IP
        COPY_TOWER
                if [[ "$SERV_TYPE" == "PRIMARY" ]]; then
                return
        fi
        done
                # STOP SOLANA on REMOTE server
        LOG "Let's stop voting on remote server "
        LOG "CHECK_UP=$CHECK_UP, HEALTH=$HEALTH, BEHIND=$BEHIND, REASON=$REASON, set_primary=$set_primary, Delinquent=$Delinquent, VOTING_IP=$VOTING_IP  "
        SEND_INFO "${NODE}.${NAME}: switch voting from ${VOTING_IP} $REASON" # \n%s vote_off remote server
        TVC1=$(solana validators --sort=credits -r -n -u $LOCAL_RPC | grep $VOTING_ADDR | awk '{print $1}')
        CREDITS_GAP_BEFORE=$(CREDITS_GAP)
        switch_start_time=$(($(date +%s%N) / 1000000)) #
        SSH "$SOL_BIN/agave-validator -l $LEDGER set-identity $EMPTY_KEY 2>&1"
#       SSH "$FD_BIN set-identity --config /root/solana/config.toml $EMPTY_KEY 2>&1"
        if [ $command_exit_status -eq 0 ]; then
                LOG "set empty identity on REMOTE server"
        else
                SEND_ALARM "Can't set identity on remote server"
                LOG "Try to restart solana on remote server"
                SSH "systemctl restart solana 2>&1"
        if [ $command_exit_status -eq 0 ]; then
                        SEND_INFO "restart solana on remote server"
        else
                        SEND_ALARM "Can't restart solana on REMOTE server, try to reboot it"
                        SSH "reboot"
                        if [ $command_exit_status -eq 0 ]; then
                                SEND_INFO "reboot REMOTE server OK"
                else
                                SEND_ALARM "Can't reboot REMOTE server"
                        fi
                        sleep 5
                        if ping -c 3 -W 1 "$REMOTE_IP" > /dev/null 2>&1; then
                                LOG "Remote server ping OK, may be it's still voting"
                                return
                        fi
                        SEND_ALARM "Can't ping REMOTE server"
                fi
        fi
        LOG "Let's start voting on current server"

        # copy tower from remote server
        if COPY_TOWER; then
        LOG "Tower copy successfully"
        fi

        : '
        # check tower age
        time_diff=200000
        if [[ -f $LEDGER/tower-1_9-$IDENTITY.bin ]]; then
                current_ms_time=$(($(date +%s%N) / 1000000)) # Get current time in milliseconds
                last_modified=$(($(date -r "$LEDGER/tower-1_9-$IDENTITY.bin" +%s%N) / 1000000)) # Get last modified time in milliseconds
                time_diff=$((current_ms_time - last_modified));
                time_diff=$(echo "scale=2; $time_diff / 1000" | bc) # convert to seconds
        fi

        # check, if remote validator 'changing' / 'stop voting'

        SSH "$SOL_BIN/agave-validator --ledger '$LEDGER' contact-info" # get remote validator info
        remote_validator=$(echo "$command_output" | grep "Identity:" | awk '{print $2}') # get remote voting identity
        if [[ "$remote_validator" == "$IDENTITY" ]]; then
                SEND_ALARM "Error! remote_validator still voting, so try to start voting later"
                LOG "remote_validator=$remote_validator, IDENTITY=$IDENTITY"
                return
        else
                LOG "Remote_validator changed OK: $remote_validator"
        fi
        '

   # START SOLANA on LOCAL server
#       agave-validator -l $LEDGER set-identity --require-tower $VOTING_KEY;
        fdctl set-identity --config /root/solana/config.toml --require-tower $VOTING_KEY;

        set_identity_status=$?
        switch_stop_time=$(($(date +%s%N) / 1000000))
        switch_time=$((switch_stop_time - switch_start_time))
        switch_time=$(echo "scale=2; $switch_time / 1000" | bc) # convert to seconds
        if [ $set_identity_status -eq 0 ]; then
                SEND_INFO "Start voting for ${switch_time}s"
        else
                SEND_ALARM "Start voting Error: $set_identity_status, can't set identity"
                return
        fi

        # restart relayer service
        if [[ -n "$RELAYER_SERVICE" ]]; then
        timeout 10 ssh "${SSH_OPTS[@]}" REMOTE  "systemctl stop $RELAYER_SERVICE" # Large timeout needed for this command
                if [ $? -eq 0 ]; then LOG "stop relayer on remote server OK"
                elif [ $? -eq 124 ]; then LOG "stop relayer on remote server timeout exceed"
                else LOG "stop relayer on remote server Error"
                fi
    SSH "systemctl disable $RELAYER_SERVICE" # ✅ with SSH_OPTS
                if [ $command_exit_status -eq 0 ]; then LOG "disable relayer on remote server OK"
                elif [ $command_exit_status -eq 124 ]; then LOG "disable relayer on remote server timeout exceed"
                else LOG "disable relayer on remote server Error"
                fi
                ln -sf ~/solana/$RELAYER_SERVICE /etc/systemd/system
                systemctl daemon-reload
                systemctl enable $RELAYER_SERVICE
                systemctl start $RELAYER_SERVICE
                agave-validator -l $LEDGER set-relayer-config --relayer-url http://127.0.0.1:11226
                LOG "restart relayer service"
        fi
        ### restart telegraf service
        SSH "systemctl stop telegraf"
        if [ $command_exit_status -eq 0 ]; then LOG "stop telegraf on remote server OK"
        elif [ $command_exit_status -eq 124 ]; then LOG "stop telegraf on remote server timeout exceed"
        else LOG "stop telegraf on remote server Error"
        fi
        SSH "systemctl disable telegraf"
        ### start telegraf service on local server
        systemctl enable telegraf
        systemctl start telegraf
        if [[ $? -ne 0 ]]; then LOG "Error! start telegraf"
        else LOG "start telegraf OK"
        fi
        sleep 2
        TVC2=$(solana validators --sort=credits -r -n -u $LOCAL_RPC | grep $VOTING_ADDR | awk '{print $1}')
        CREDITS_GAP_AFTER=$(CREDITS_GAP)
        TVC_DIFF=$((TVC2 - TVC1))
        CREDITS_LOSS=$((CREDITS_GAP_BEFORE - CREDITS_GAP_AFTER))
        LOG "waiting for PRIMARY status, TVC=$TVC2(-$TVC_DIFF), CREDITS_LOSS=$CREDITS_LOSS"
        #while [ $SERV_TYPE = "SECONDARY" ]; do
                # LOG "waiting for PRIMARY status"
                #GET_VOTING_IP
        #CHECK_HEALTH
        #done
        }

##########################################################################

echo "";
LATEST_TAG_URL=https://api.github.com/repos/Hohlas/solana-guard/releases/latest
LATEST_TAG=$(curl -sSL "$LATEST_TAG_URL" | jq -r '.tag_name')

if [ "$LATEST_TAG" != "$GUARD_VER" ]; then
  echo -e " == ${BLUE}SOLANA GUARD ${GUARD_VER}${CLEAR} ==  ${GRAY}run '${CLEAR}${GREEN}guard u${CLEAR}${GRAY}' to update to ${LATEST_TAG} release${CLEAR}" | tee -a $LOG_FILE
else
  echo -e " ==$BLUE SOLANA GUARD $GUARD_VER $CLEAR ==  " | tee -a $LOG_FILE
fi

argument=$1 # read script argument
primary_mode=''
behind_threshold="0"
if [[ $argument =~ ^[0-9]+$ ]] && [ "$argument" -gt 0 ]; then
    behind_threshold=$argument #
        echo -e "$RED behind threshold = $behind_threshold  $CLEAR"
elif [[ $argument == "p" ]]; then
        primary_mode='permanent_primary';
        read -p "Do you realy want to set PERMANENT PRIMARY mode? (y/n)" RESP; if [ "$RESP" != "y" ]; then exit 1; fi
        echo -e " WARNING!!! $RED PERMANENT PRIMARY mode $CLEAR !!!"
elif [[ $argument == "u" ]]; then
        curl -sSL https://raw.githubusercontent.com/Hohlas/solana-guard/$LATEST_TAG/guard.sh > $HOME/solana-guard/guard.sh
        curl -sSL https://raw.githubusercontent.com/Hohlas/solana-guard/$LATEST_TAG/check.sh > $HOME/solana-guard/check.sh
        chmod +x ~/solana-guard/guard.sh
        chmod +x ~/solana-guard/check.sh
        echo -e " Updated to latest release$BLUE $LATEST_TAG $CLEAR"
        return
fi

GET_VOTING_IP
#echo "ledger path: [$LEDGER]"
echo "voting  IP=$VOTING_IP" | tee -a $LOG_FILE
echo "current IP=$CUR_IP" | tee -a $LOG_FILE
echo -e "IDENTITY  = $GREEN$IDENTITY $CLEAR" | tee -a $LOG_FILE
echo -e "empty addr = $GRAY$EMPTY_ADDR $CLEAR" | tee -a $LOG_FILE
if [[ -z "$rpc_index" ]]; then # rpc_index not defined
        LOG "rpc_index not defined in $LOG_FILE, set default value rpc_index=0"
        rpc_index=0; # Set default value
fi
echo " Helius rpc_index=$rpc_index, rpcURL list:"
for rpcURL in "${RPC_LIST[@]}"; do
        echo -e "$GRAY$rpcURL$CLEAR" | tee -a $LOG_FILE
done
rpcURL2="${RPC_LIST[$rpc_index]}" # Get current RPC URL from list
if [ -z "$NAME" ]; then NAME=$(hostname); fi
if [ $rpcURL1 = https://api.testnet.solana.com ]; then
NODE="test"
elif [ $rpcURL1 = https://api.mainnet-beta.solana.com ]; then
NODE="main"
fi
echo -e " $BLUE$NODE.$NAME $YELLOW$version $client $CLEAR"

if [[ "$SERV_TYPE" == "PRIMARY" ]]; then # PRIMARY can't determine REMOTE_IP of SECONDARY
        if [ -f $HOME/solana-guard/remote_ip ]; then # SECONDARY should have written its IP to PRIMARY
                REMOTE_IP=$(cat $HOME/solana-guard/remote_ip) # echo "get REMOTE_IP of SECONDARY_SERVER from $HOME/solana-guard/remote_ip: $REMOTE_IP"
        else
                REMOTE_IP=''
        fi
        if [[ -z $REMOTE_IP ]]; then # if $REMOTE_IP empty
                echo -e "Warning! Run guard on SECONDARY server first to get it's IP"
                return
        fi
elif [[ "$SERV_TYPE" == "SECONDARY" ]]; then # SECONDARY
        REMOTE_IP=$VOTING_IP # it's true for SECONDARY
else
        echo -e "Warning! Server type (PRIMARY/SECONDARY) undefined"
        echo "local_validator=$local_validator"
        echo "SERV_TYPE=$SERV_TYPE"
        return
fi

chmod 600 $KEYS/*.ssh
eval "$(ssh-agent -s)"  # Start ssh-agent in the background
ssh-add $KEYS/*.ssh # Add SSH private key to the ssh-agent
# prepare SSH config directories and include
mkdir -p "$HOME/.ssh/cm" "$HOME/.ssh/config.d"
if [ ! -f "$HOME/.ssh/config" ] || ! grep -q "^Include .*config.d/\\*.conf$" "$HOME/.ssh/config" 2>/dev/null; then
  echo "Include ~/.ssh/config.d/*.conf" >> "$HOME/.ssh/config"
fi

# create/update ssh alias for remote server in dedicated file
cat > "$HOME/.ssh/config.d/guard_ssh.conf" <<EOF
Host REMOTE
    HostName $REMOTE_IP
    User $USER
    Port $PORT
    IdentityFile $KEYS/*.ssh

    ControlMaster auto
        ControlPath ~/.ssh/cm/%r@%h:%p # socket file for each connection ControlPath ~/.ssh/cm/%C
    ControlPersist 300

    ConnectTimeout 5
    ServerAliveInterval 30
    ServerAliveCountMax 3

    LogLevel ERROR
EOF

# check remote server SSH connection (by reading Identity addr)
timeout 9 ssh "${SSH_OPTS[@]}" REMOTE "echo ssh connection OK"
if [ $? -ne 0 ]; then
    echo "Can not connect by SSH to remote server!
        HostName: $REMOTE_IP
        User: $USER
        Port: $PORT
        IdentityFile: $KEYS/*.ssh
        "
fi
SSH "$SOL_BIN/solana address"
if [ $command_exit_status -eq  0 ]; then
        remote_identity=$command_output
        echo "Checking solana on remote server OK"
else
        echo -e "$RED Can't run solana on remote server $CLEAR, is it exist $SOL_BIN/solana"
        return
fi

# compare servers identities
if [ "$remote_identity" != "$IDENTITY" ]; then
    echo -e "$RED Warning! Servers identities are different $CLEAR"
        echo "Current Identity = $IDENTITY"
        echo "Remote Identity  = $remote_identity"
        echo "Check 'solana config get' on both servers"
        return
fi

# check remote server validator addr
SSH "$SOL_BIN/agave-validator --ledger '$LEDGER' contact-info" # get remote validator info
remote_validator=$(echo "$command_output" | grep "Identity:" | awk '{print $2}') # get remote voting identity
if [ -z "$remote_validator" ]; then
        echo -e "$RED remote_validator is missing  $CLEAR"
        echo "Check path: '$LEDGER' on remote server"
        return
fi

# check remote empty addr
SSH "$SOL_BIN/solana address -k $EMPTY_KEY"
remote_empty=$command_output
if [ -z "$remote_empty" ]; then
        echo -e "$RED remote_empty_key is missing  $CLEAR"
        return
fi

# check remote status
if [[ "$remote_validator" == "$IDENTITY" ]]; then
        REMOTE_SERVER_STATUS="Primary"
elif [[ "$remote_validator" == "$remote_empty" ]]; then
        REMOTE_SERVER_STATUS="Secondary"
else
        echo -e "$RED remote server unknown status  $CLEAR"
        echo "remote validator: $remote_validator"
        echo "remote empty addr: $remote_empty"
        echo "identity addr: $IDENTITY"
        return
fi

echo -e "$GREEN Remote Server checkup successful $CLEAR" | tee -a $LOG_FILE
echo " remote identity  = $remote_identity"
echo " remote validator = $remote_validator"
echo " remote empty_adr = $remote_empty"
echo " remote server IP = $REMOTE_IP"
echo " remote server    = $REMOTE_SERVER_STATUS"

echo '0' > $HOME/solana-guard/remote_behind # update local file for stop alarm next 600 seconds
SSH "echo '$CUR_IP' > $HOME/solana-guard/remote_ip" # send 'current IP' to remote server

while true  ###  main cycle   #################################################
do
        GET_VOTING_IP
        if [[ "$SERV_TYPE" == "PRIMARY" ]]; then
                PRIMARY_SERVER
        elif [[ "$SERV_TYPE" == "SECONDARY" ]]; then
                SECONDARY_SERVER
        else
                SEND_ALARM "Server type undefined"
        fi
done
