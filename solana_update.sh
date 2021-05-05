# Taken from https://www.youtube.com/watch?v=vzozlM-5Hq8

solana --version && solana slot && solana-install update
# 1.6.7
# 71876724
# installed

# try to find free space to reload service while not generating block
solana leader-schedule -u localhost | grep $(solana address) | grep $(solana slot | cut -c 1-4)

# look through snapshot close to current slot #
#ls -la /root/solana/ledger/snapshot*tar*

#-rw-r--r-- 1 root root  179951193 Apr 10 10:52 snapshot-71030051-8DZKXZNi9TS4uqVpWwbqHRZczDcZCxcJaWpVz5FSDW6W.tar.zst
#-rw-r--r-- 1 root root 2168606720 Apr 14 21:14 snapshot-71876032-9hgot9X1KJJ1C7Es2PFW3sf7zS8oQPgzzqmzcWcxL4Q.tar
#-rw-r--r-- 1 root root 2167183360 Apr 14 21:18 snapshot-71876588-2ScbsPKBorFvpNm4Jn5R264oWuaPmhNZGFEn52KrYkdJ.tar

#When you have time - install and wait for catchup
solana-install update && systemctl restart solana && sleep 30 && solana catchup /root/solana/validator-keypair.json --our-localhost
