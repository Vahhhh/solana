#!/bin/bash
# modified from https://github.com/yatsvic/solana-scripts/blob/main/see-schedule.sh -BIG THANKS!!!
#Show Approximate Slot Timestamps

pushd `dirname ${0}` > /dev/null || exit 1
#source ./env.sh

#from https://stackoverflow.com/a/58617630OD
function durationToSeconds () {
  set -f
  normalize () { echo $1 | tr '[:upper:]' '[:lower:]' | tr -d "\"\\\'" | sed 's/years\{0,1\}/y/g; s/months\{0,1\}/m/g; s/days\{0,1\}/d/g; s/hours\{0,1\}/h/g; s/minutes\{0,1\}/m/g; s/min/m/g; s/seconds\{0,1\}/s/g; s/sec/s/g;  s/ //g;'; }
  local value=$(normalize "$1")
  local fallback=$(normalize "$2")

  echo $value | grep -v '^[-+*/0-9ydhms]\{0,30\}$' > /dev/null 2>&1
  if [ $? -eq 0 ]
  then
    >&2 echo Invalid duration pattern \"$value\"
  else
    if [ "$value" = "" ]; then
      [ "$fallback" != "" ] && durationToSeconds "$fallback"
    else
      sedtmpl () { echo "s/\([0-9]\+\)$1/(0\1 * $2)/g;"; }
      local template="$(sedtmpl '\( \|$\)' 1) $(sedtmpl y '365 * 86400') $(sedtmpl d 86400) $(sedtmpl h 3600) $(sedtmpl m 60) $(sedtmpl s 1) s/) *(/) + (/g;"
      echo $value | sed "$template" | bc
    fi
  fi
  set +f
}

#NOW=`date --iso-8601=seconds`
NOW=`TZ='UTC-3' date +"%F %T"`
NOW_SEC=`date +%s`
EPOCH_INFO=`solana --url=localhost epoch-info`
SOLANA_VALIDATOR_PUB_KEY=`solana address`
SCHEDULE=`solana --url=localhost leader-schedule | grep ${SOLANA_VALIDATOR_PUB_KEY}`

FIRST_SLOT=`echo -e "$EPOCH_INFO" | grep "Epoch Slot Range: " | cut -d '[' -f 2 | cut -d '.' -f 1`
LAST_SLOT=`echo -e "$EPOCH_INFO" | grep "Epoch Slot Range: " | cut -d '[' -f 2 | cut -d '.' -f 3 | cut -d ')' -f 1`
CURRENT_SLOT=`echo -e "$EPOCH_INFO" | grep "Slot: " | cut -d ':' -f 2 | cut -d ' ' -f 2`
EPOCH_LEN_TEXT=`echo -e "$EPOCH_INFO" | grep "Completed Time" | cut -d '/' -f 2 | cut -d '(' -f 1`
EPOCH_LEN_SEC=$(durationToSeconds "${EPOCH_LEN_TEXT}")
SLOT_LEN_SEC=`echo "scale=10; ${EPOCH_LEN_SEC}/(${LAST_SLOT}-${FIRST_SLOT})" | bc`
SLOT_PER_SEC=`echo "scale=10; 1.0/${SLOT_LEN_SEC}" | bc`
COMPLETED_SLOTS=`echo -e "${SCHEDULE}" | awk -v cs="${CURRENT_SLOT}" '{ if ($1 <= cs) { print }}' | wc -l`
REMAINING_SLOTS=`echo -e "${SCHEDULE}" | awk -v cs="${CURRENT_SLOT}" '{ if ($1 > cs) { print }}' | wc -l`
TOTAL_SLOTS=`echo -e "${SCHEDULE}" | wc -l`

function slotDate () {
  local SLOT=${1}
  local SLOT_DIFF=`echo "${SLOT}-${CURRENT_SLOT}" | bc`
  local DELTA=`echo "(${SLOT_LEN_SEC}*${SLOT_DIFF})/1" | bc`
  local SLOT_DATE_SEC=`echo "${NOW_SEC} + ${DELTA}" | bc`
  local DATE_TEXT=`TZ='UTC-3' date +"%F %T" -d @${SLOT_DATE_SEC}`
  echo "${DATE_TEXT}"
}

CYAN='\033[0;36m'
RED='\033[0;31m'
GREEN='\033[0;32m'
NOCOLOR='\033[0m'

function slotColor() {
  local SLOT=${1}
  local COLOR=`
    if (( ${SLOT} <= ${CURRENT_SLOT} )); then
      echo "${RED}old< "
    else
      echo "${GREEN}new> "
    fi`
  echo -e "${COLOR}"
}
echo "${NOW}"
echo "Speed: ${SLOT_PER_SEC} slots per second"
echo " Time: ${SLOT_LEN_SEC} seconds per slot"
echo "My Slots ${COMPLETED_SLOTS}/${TOTAL_SLOTS} (${REMAINING_SLOTS} remaining)"
echo
echo "${EPOCH_INFO}"
echo
echo -e "${CYAN}Start:   `slotDate ${FIRST_SLOT}`${NOCOLOR}"
echo "${SCHEDULE}" | sed 's/|/ /' | awk '{print $1}' | while read in; do
COLOR=`slotColor ${in}`
echo -e "${COLOR}$in `slotDate ${in}`${NOCOLOR}";
done
echo -e "${CYAN}End:     `slotDate ${LAST_SLOT}`${NOCOLOR}"
popd > /dev/null || exit 1
