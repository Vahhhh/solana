# Taken from https://www.youtube.com/watch?v=vzozlM-5Hq8

solana --version
#solana-cli 1.6.4

solana-install update
# Update successful to 1.6.6

solana slot
# 71876724

# try to find free space to reload service while not generating block by or node - 4P8
solana leader-schedule -u localhost | grep 4P8 | grep 7187 
# 7187 = first 4 counts of block #

# look through snapshot close to current slot # 
ls -la /root/solana/ledger/snapshot*tar*

#-rw-r--r-- 1 root root  179951193 Apr 10 10:52 snapshot-71030051-8DZKXZNi9TS4uqVpWwbqHRZczDcZCxcJaWpVz5FSDW6W.tar.zst
#-rw-r--r-- 1 root root 2168606720 Apr 14 21:14 snapshot-71876032-9hgot9X1KJJ1C7Es2PFW3sf7zS8oQPgzzqmzcWcxL4Q.tar
#-rw-r--r-- 1 root root 2167183360 Apr 14 21:18 snapshot-71876588-2ScbsPKBorFvpNm4Jn5R264oWuaPmhNZGFEn52KrYkdJ.tar

systemctl restart solana

solana catchup /root/solana/validator-keypair.json --our-localhost

solana slot
