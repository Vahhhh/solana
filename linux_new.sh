#!/bin/bash

export PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND$'\n'}history -a; history -c; history -r;"
export HISTTIMEFORMAT='%F %T '

sudo systemctl stop snapd && sudo systemctl disable snapd && sudo apt purge snapd -y && rm -rf ~/snap && sudo rm -rf /snap /var/snap /var/lib/snapd /var/cache/snapd /usr/lib/snapd /root/snap
