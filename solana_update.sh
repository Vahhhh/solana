# Taken from https://www.youtube.com/watch?v=vzozlM-5Hq8

#solana --version && solana slot && solana-install update
# 1.6.7
# 71876724
# installed

# try to find free space to reload service while not generating block
# need file see-schedule.sh in the same directory
#./see-schedule.sh | grep -m1 -A11 "new>" | sed -n -e 1p -e 5p -e 9p

# look through snapshot close to current slot #
#ls -la /root/solana/ledger/snapshot*tar*

#-rw-r--r-- 1 root root  179951193 Apr 10 10:52 snapshot-71030051-8DZKXZNi9TS4uqVpWwbqHRZczDcZCxcJaWpVz5FSDW6W.tar.zst
#-rw-r--r-- 1 root root 2168606720 Apr 14 21:14 snapshot-71876032-9hgot9X1KJJ1C7Es2PFW3sf7zS8oQPgzzqmzcWcxL4Q.tar
#-rw-r--r-- 1 root root 2167183360 Apr 14 21:18 snapshot-71876588-2ScbsPKBorFvpNm4Jn5R264oWuaPmhNZGFEn52KrYkdJ.tar

#When you have time - install and wait for catchup
#solana-install update && systemctl restart solana && sleep 30 && solana catchup /root/solana/validator-keypair.json --our-localhost

apt install -y screen && screen -AdmS solana /bin/bash -c 'solana-install init 1.10.10 && solana-validator --ledger /root/solana/ledger/ wait-for-restart-window --max-delinquent-stake 10 && systemctl restart solana && err=1; while [ $err -eq 1 ]; do solana catchup /root/solana/validator-keypair.json --our-localhost; err=$?; sleep 5; done'
