
mdadm -D /dev/md4 | grep -e "Array Size" -e "Dev Size" && \
mdadm --grow /dev/md4 -z 41943168 && \
mdadm /dev/md4 --fail /dev/nvme1n1p4 --remove /dev/nvme1n1p4 && \
yes | parted -a opt /dev/nvme1n1 resizepart 4 90GB && \
mdadm -a /dev/md4 /dev/nvme1n1p4 && \
until grep -A1 md4 /proc/mdstat | grep -m 1 "UU"; do grep recovery /proc/mdstat && sleep 10 ; done && \
mdadm /dev/md4 --fail /dev/nvme0n1p4 --remove /dev/nvme0n1p4 && \
yes | parted -a opt /dev/nvme0n1 resizepart 4 90GB && \
mdadm -a /dev/md4 /dev/nvme0n1p4 && \
until grep -A1 md4 /proc/mdstat | grep -m 1 "UU"; do grep recovery /proc/mdstat && sleep 10 ; done && \
parted -a opt /dev/nvme0n1 mkpart primary ext4 90.0GB 100% && \
parted -a opt /dev/nvme1n1 mkpart primary ext4 90.0GB 100% && \
mdadm --create --verbose /dev/md5 --level=0 --raid-devices=2 /dev/nvme0n1p5 /dev/nvme1n1p5 && \
sudo mdadm --detail --scan | sudo tee -a /etc/mdadm/mdadm.conf && \
sudo update-initramfs -u && \
pvresize /dev/md4 --setphysicalvolumesize 42949804032b && \
mkfs.ext4 /dev/md5 && \
pvcreate /dev/md5 && \
vgcreate vg01 /dev/md5 && \
lvcreate -L 1T -n solana vg01 && \
lvcreate -L 135G -n swap vg01 && \
mkfs.ext4 /dev/vg01/solana && \
mkfs.ext4 /dev/vg01/swap && \
echo '/dev/vg01/solana /root/solana   ext4    defaults                0 0' >> /etc/fstab && \
echo '/dev/vg01/swap   /mnt/swap      ext4    defaults                0 0' >> /etc/fstab && \
echo '/mnt/swap/swapfile none swap sw 0 0' >> /etc/fstab && \
mkdir -p /root/solana && \
mount /dev/vg01/solana && \
mkdir -p /mnt/swap && \
mount /dev/vg01/swap && \
swapoff -a && \
dd if=/dev/zero of=/mnt/swap/swapfile bs=1G count=128 && \
chmod 600 /mnt/swap/swapfile && \
mkswap /mnt/swap/swapfile && \
swapon /mnt/swap/swapfile && \
echo 'tmpfs /mnt/ramdisk tmpfs nodev,nosuid,noexec,nodiratime,size=100G 0 0' >> /etc/fstab && \
mkdir -p /mnt/ramdisk && \
mount /mnt/ramdisk
