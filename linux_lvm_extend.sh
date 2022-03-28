
parted -s /dev/sda "resizepart 3 100%" quit
pvresize /dev/sda3
pvscan
lvextend -l +100%FREE --resizefs /dev/mapper/ubuntu--vg-ubuntu--lv
