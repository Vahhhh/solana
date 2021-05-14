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
##### or
##### Resize partition to 50Gb (inside parted)
```
parted
(parted) print list
(parted) select /dev/nvme1n1
(parted) resizepart 4 90GB
Warning: Shrinking a partition can cause data loss, are you sure you want to continue?
Yes/No? Yes
```
##### Add disk to /dev/md4
`mdadm -a /dev/md4 /dev/nvme1n1p4`

##### Waiting until RAID sync
`until grep -A1 md4 /proc/mdstat | grep -m 1 "UU"; do sleep 1 ; done`
##### or
`watch -n 3 cat /proc/mdstat`

## Decreasing the Size of 2st partition

##### Remove 2nd disk from /dev/md4
`mdadm /dev/md4 --fail /dev/nvme0n1p4 --remove /dev/nvme0n1p4`

##### Resize partition to 50Gb (one command)
`parted -a opt /dev/nvme1n1 resizepart 4 90GB`
##### or
##### Resize partition to 50Gb (inside parted)
```
parted
(parted) select /dev/nvme0n1
(parted) print list
(parted) resizepart 4 90GB
Warning: Shrinking a partition can cause data loss, are you sure you want to continue?
Yes/No? Yes
```

##### Add disk to /dev/md4
`mdadm -a /dev/md4 /dev/nvme0n1p4`

##### Waiting until RAID sync
`until grep -A1 md4 /proc/mdstat | grep -m 1 "UU"; do sleep 1 ; done`
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

##### Update initramfs
`sudo update-initramfs -u`


##### Change /dev/md4 PV size
`pvresize /dev/md4 --setphysicalvolumesize 42949804032b`


##### Format /dev/md5
`mkfs.ext4 /dev/md5`

```
# fio --randrepeat=1 --ioengine=libaio --direct=1 --gtod_reduce=1 --name=fiotest --filename=testfio --bs=4k --iodepth=64 --size=8G --readwrite=randrw --rwmixread=75

Jobs: 1 (f=1): [m(1)][100.0%][r=961MiB/s,w=323MiB/s][r=246k,w=82.6k IOPS][eta 00m:00s]
  read: IOPS=249k, BW=972MiB/s (1020MB/s)(6141MiB/6315msec)
  write: IOPS=83.1k, BW=325MiB/s (341MB/s)(2051MiB/6315msec); 0 zone resets
```

##### Save mount info to /etc/fstab
`echo '/dev/md5        /root/solana    ext4    defaults                0 0' >> /etc/fstab`

##### Mount /root/solana to RAID0
`mkdir /root/solana && mount /dev/md5`


> If you want to use RAID0 with LVM
> Create new LVM /dev/md5 (SEEM TO BE NOT SO FAST!!!)
> ```
> pvcreate /dev/md5
> vgcreate vg01 /dev/md5
> lvcreate -L 1T -n solana vg01
> ```
> ```
> fio --randrepeat=1 --ioengine=libaio --direct=1 --gtod_reduce=1 --name=fiotest --filename=testfio --bs=4k --iodepth=64 --size=8G --readwrite=randrw --rwmixread=75
> 
> Jobs: 1 (f=1): [m(1)][100.0%][r=845MiB/s,w=283MiB/s][r=216k,w=72.4k IOPS][eta 00m:00s]
>   read: IOPS=219k, BW=857MiB/s (899MB/s)(6141MiB/7165msec)
>   write: IOPS=73.3k, BW=286MiB/s (300MB/s)(2051MiB/7165msec); 0 zone resets
> ```
