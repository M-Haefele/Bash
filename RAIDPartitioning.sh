#!/bin/bash

#it is advisable to run this shell script as sudoer, however, this script may be deprecated, check commands and how they impact your current kernel

#this script uses loopback devices to imitate RAID configurations instead of /dev/sdX, but you can substitute these devices

#this script is not persistent, you will need to additionally run a few commands to update your image


#bash script for configuring RAID 5 and 6 on an Ubuntu vm

#check if current Ubuntu LTS is most recent
#apt-get update
#apt-get upgrade
echo "Your current OS is up to date."
echo "`lsb_release -a`"

echo "create loopback devices for use in RAID/LVM?(Y/N)"
read input
if [ $input = "Y" ]; then
	echo "Creating loopback  devices"
    for dev in LP1 LP2 LP3 LP4 ; do
    dd if=/dev/zero of=$dev.img bs=100M count=40
    du -sh $dev.img
    #mount as a loop device
    losetup -fP $dev.img
    done
    #display dev/loopX currently mounted as loopback device just made 
	losetup -a
fi


#error handling for improper dev count as cmd line args
if [ $# -ne 4 ]
then
	echo "Usage: sudo bash RAIDPartitioning.sh <dev1> <dev2> <dev3> <dev4>"
	echo "You must provide exactly 4 devices"
exit
fi
		


#for device in command line args if dev exist nothing else no device found, exiting
for var in $@; do
    if [ -b $var ]
		then 
		echo "$var: Device found"
	else 
	    echo "$var is not a block device"
		exit
    fi
done

#parition logic for first 3 disks, non-interactive partition table creation
echo " creating partition tables.."

#fdisk 2G for 1st pass, 1 for 2 and 3, 4th dev is 2/2
for dev in $1 $2 $3 ;do
	(
	echo o
	echo n
	echo p	
	echo 1
	echo	
	echo +2G
	echo n
	echo p 	
	echo 2
	echo
	echo +1G
	echo n
	echo p
	echo 3
	echo
	echo 
	echo w
	) | fdisk $dev
done


    (
        echo o
        echo n
        echo p  
        echo 1
        echo    
        echo +2G
        echo n
        echo p  
        echo 2
        echo
        echo 
        echo w
        ) | fdisk $4

lsblk 

#d1-d3 2/1/1 d4 

apt-get install mdadm

echo "mdadm installed, creating RAID 5 and 6 configurations for selected devices..."

lsblk -o NAME,SIZE,FSTYPE,TYPE,MOUNTPOINT

sudo mdadm --create --verbos /dev/md0 --level=6 --raid-devices=4 ${1}p1 ${2}p1 ${3}p1 ${4}p1

echo "RAID 6 Configuration on md0 created"

echo "Displaying active RAID configurations..."

cat /proc/mdstat | grep ^md

echo "Mounting md0 to filesystem..."

sudo mkfs.ext4 -F /dev/md0
sudo mkdir -p /mnt/md0
sudo mount /dev/md0 /mnt/md0
df -h -x devtmpfs -x tmpfs

echo "Saving RAID config..."

sudo mdadm --detail --scan | sudo tee -a /etc/mdadm/mdadm.conf

sudo update-initramfs -u

echo 'dev/md0 /mnt/md0 ext4 defaults,nofail,discard 0 0' | sudo tee -a /etc/fstab

echo "RAID 6 will automatically  assemble and mount each boot"


sudo mdadm --create --verbose /dev/md1 --level=5 --raid-devices=3 ${1}p2 ${2}p2 ${3}p2

echo "RAID 5 on md1 created"

echo "Mounting md1 to filesystem"

sudo mkfs.ext4 -F /dev/md1
sudo mkdir -p /mnt/md1
sudo mount /dev/md1 /mnt/md1
df -h -x devtmpfs -x tmpfs

echo "Saving RAID config..."

sudo mdadm --detail --scan | sudo tee -a /etc/mdadm/mdadm.conf

sudo update-initramfs -u

echo 'dev/md1 /mnt/md1 ext4 defaults,nofail,discard 0 0' | sudo tee -a /etc/fstab


echo "Displaying active RAID configurations..."

cat /proc/mdstat | grep ^md

