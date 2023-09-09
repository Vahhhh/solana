#!/bin/bash

export PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND$'\n'}history -a; history -c; history -r;"
export HISTTIMEFORMAT='%F %T '
