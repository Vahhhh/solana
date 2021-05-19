# Resize RAID1 array + add RAID0

made with help of:

https://documentation.suse.com/sles/12-SP4/html/SLES-all/cha-raid-resize.html#sec-raid-resize-decr

https://winitpro.ru/index.php/2020/07/09/parted-upravlenie-razdelami-linux/


## Decreasing the Size of the RAID Array to 40Gb

##### Check
```
mdadm -D /dev/md4 | grep -e "Array Size" -e "Dev Size"
        Array Size : 898628416 (857.00 GiB 920.20 GB)
     Used Dev Size : 898628416 (857.00 GiB 920.20 GB)
```
##### Do
`mdadm --grow /dev/md4 -z 41943168`

##### Check changes
```
mdadm -D /dev/md4 | grep -e "Array Size" -e "Dev Size"
        Array Size : 41943168 (40.00 GiB 42.95 GB)
     Used Dev Size : 41943168 (40.00 GiB 42.95 GB)
```

## Decreasing the Size of 1st partition

##### Remove 1st disk from /dev/md4
`mdadm /dev/md4 --fail /dev/nvme1n1p4 --remove /dev/nvme1n1p4`

##### Resize partition to 50Gb (one command)
`parted -a opt /dev/nvme1n1 resizepart 4 90GB`

>##### or
>##### Resize partition to 50Gb (inside parted)
>```
>parted
>(parted) print list
>(parted) select /dev/nvme1n1
>(parted) resizepart 4 90GB
>Warning: Shrinking a partition can cause data loss, are you sure you want to continue?
>Yes/No? Yes
>```

##### Add disk to /dev/md4
`mdadm -a /dev/md4 /dev/nvme1n1p4`

##### Waiting until RAID sync
`until grep -A1 md4 /proc/mdstat | grep -m 1 "UU"; do grep recovery /proc/mdstat && sleep 10 ; done`
##### or
`watch -n 3 cat /proc/mdstat`

## Decreasing the Size of 2st partition

##### Remove 2nd disk from /dev/md4
`mdadm /dev/md4 --fail /dev/nvme0n1p4 --remove /dev/nvme0n1p4`

##### Resize partition to 50Gb (one command)
`parted -a opt /dev/nvme0n1 resizepart 4 90GB`

>##### or
>##### Resize partition to 50Gb (inside parted)
>```
>parted
>(parted) select /dev/nvme0n1
>(parted) print list
>(parted) resizepart 4 90GB
>Warning: Shrinking a partition can cause data loss, are you sure you want to continue?
>Yes/No? Yes
>```

##### Add disk to /dev/md4
`mdadm -a /dev/md4 /dev/nvme0n1p4`

##### Waiting until RAID sync
`until grep -A1 md4 /proc/mdstat | grep -m 1 "UU"; do grep recovery /proc/mdstat && sleep 10 ; done`
##### or
`watch -n 3 cat /proc/mdstat`

## Creating new partition for /root/solana

##### Create partition on 1st disk
`parted -a opt /dev/nvme0n1 mkpart primary ext4 90.0GB 100%`

##### Create partition on 2nd disk
`parted -a opt /dev/nvme1n1 mkpart primary ext4 90.0GB 100%`

##### Create RAID0
`mdadm --create --verbose /dev/md5 --level=0 --raid-devices=2 /dev/nvme0n1p5 /dev/nvme1n1p5`

##### Save RAID config to mdadm.comf
`sudo mdadm --detail --scan | sudo tee -a /etc/mdadm/mdadm.conf`

##### Comment 2 previous raid configurations

##### Update initramfs
`sudo update-initramfs -u`

##### Change /dev/md4 PV size
`pvresize /dev/md4 --setphysicalvolumesize 42949804032b`

##### Create RAID0 with LVM /dev/vg01/solana
```
pvcreate /dev/md5
vgcreate vg01 /dev/md5
lvcreate -L 1T -n solana vg01
lvcreate -L 135G -n swap vg01
mkfs.ext4 /dev/vg01/solana
mkfs.ext4 /dev/vg01/swap
```

##### Save mount info to /etc/fstab
```
echo '/dev/vg01/solana /root/solana   ext4    defaults                0 0' >> /etc/fstab
echo '/dev/vg01/swap   /mnt/swap      ext4    defaults                0 0' >> /etc/fstab
echo '/mnt/swap/swapfile none swap sw 0 0' >> /etc/fstab
```

##### Mount /root/solana to RAID0
```
mkdir -p /root/solana && mount /dev/vg01/solana
```

##### Mount /mnt/swapfile to RAID0
```
mkdir -p /mnt/swap && mount /dev/vg01/swap
```

##### Making speed test
```
apt install fio -y
cd /root/solana
curl -sL https://github.com/masonr/yet-another-bench-script/raw/master/yabs.sh | bash -s -- -ig

# ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## #
#              Yet-Another-Bench-Script              #
#                     v2020-12-29                    #
# https://github.com/masonr/yet-another-bench-script #
# ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## #

Sun 16 May 2021 10:23:13 AM UTC

Basic System Information:
---------------------------------
Processor  : AMD Ryzen 7 PRO 3700 8-Core Processor
CPU cores  : 16 @ 2202.349 MHz
AES-NI     : ✔ Enabled
VM-x/AMD-V : ✔ Enabled
RAM        : 62.8 GiB
Swap       : 18.6 GiB
Disk       : 1.0 TiB

fio Disk Speed Tests (Mixed R/W 50/50):
---------------------------------
Block Size | 4k            (IOPS) | 64k           (IOPS)
  ------   | ---            ----  | ----           ----
Read       | 772.83 MB/s (193.2k) | 1.42 GB/s    (22.2k)
Write      | 774.87 MB/s (193.7k) | 1.43 GB/s    (22.3k)
Total      | 1.54 GB/s   (386.9k) | 2.85 GB/s    (44.6k)
           |                      |
Block Size | 512k          (IOPS) | 1m            (IOPS)
  ------   | ---            ----  | ----           ----
Read       | 1.51 GB/s     (2.9k) | 1.63 GB/s     (1.5k)
Write      | 1.59 GB/s     (3.1k) | 1.74 GB/s     (1.6k)
Total      | 3.11 GB/s     (6.0k) | 3.37 GB/s     (3.2k)

```


## swapfile
### create swapfile
```
swapoff -a && \
dd if=/dev/zero of=/mnt/swap/swapfile bs=1G count=128 && \
chmod 600 /mnt/swap/swapfile && \
mkswap /mnt/swap/swapfile && \
swapon /mnt/swap/swapfile
```

## ramdisk
### add to /etc/fstab
```
echo 'tmpfs /mnt/ramdisk tmpfs nodev,nosuid,noexec,nodiratime,size=100G 0 0' >> /etc/fstab
```

***comment other swaps in /etc/fstab NOW!!!***

```
mkdir -p /mnt/ramdisk
mount /mnt/ramdisk
```
