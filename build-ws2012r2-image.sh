#!/bin/bash
set -e

IMAGE=windows-server-2012-r2.qcow2
FLOPPY=Autounattend.vfd
VIRTIO_ISO=virtio-win-0.1-52.iso 
ISO=/mnt/hgfs/ISO/9600.16384.WINBLUE_RTM.130821-1623_X64FRE_SERVER_EVAL_EN-US-IRM_SSS_X64FREE_EN-US_DV5.ISO 
IMAGE_NAME="Windows Server 2012 R2 Std Eval QCOW2"
VM_NAME=vm1

KVM=/usr/libexec/qemu-kvm
if [ ! -f "$KVM" ]; then 
    KVM=/usr/bin/kvm;
fi

if [ -f $IMAGE ]; then
    rm $IMAGE
fi

qemu-img create -f qcow2 -o preallocation=metadata $IMAGE 16G
iptables -I INPUT -p tcp --dport 5901 -j ACCEPT
$KVM -m 2048 -smp 2 -cdrom $ISO -drive file=$VIRTIO_ISO,index=3,media=cdrom -fda $FLOPPY $IMAGE -boot d -vga std -k en-us -vnc :1

if [ -n `glance image-show "$IMAGE_NAME" > /dev/null && echo "1" || true` ]; then
    glance image-delete "$IMAGE_NAME"
fi

glance image-create --property hypervisor_type=qemu --name "$IMAGE_NAME" --container-format bare --disk-format qcow2 < $IMAGE

# Save some space and get the "master image" ready
gzip "$IMAGE"
#mv "$IMAGE.gz" /mnt/hgfs/Downloads/

#Make sure to have networking properly configured
#E.g.: https://raw.github.com/cloudbase/openstack-dev-scripts/master/quantum-create-networks.sh

NET_ID=`neutron net-show net1 | awk '{if (NR == 5) {print $4}}'`
nova boot  --flavor fl4 --image "$IMAGE_NAME" --key-name key1 --nic net-id=$NET_ID --meta admin_pass=Passw0rd --poll $VM_NAME

VM_ID=`nova show $VM_NAME | /bin/awk '{if (NR == 16) {print $4}}'`
PORT_ID=`neutron port-list -- --device_id $VM_ID | /bin/awk '{if (NR == 4) {print $2}}'`
FLOAT_IP_ID=`neutron floatingip-list | /bin/awk '{if (NR == 4) {print $2}}'`
neutron floatingip-associate $FLOAT_IP_ID $PORT_ID

FLOAT_IP=`neutron floatingip-show $FLOAT_IP_ID | /bin/awk '{if (NR == 5) {print $4}}'`

echo "IP address: $FLOAT_IP"

# Wait for cloudbase-init to run
# Automated test requires the WinRM plugin, not yet available
sleep 300

# Check password depployment
PASSWORD=`nova get-password $VM_ID ~/.ssh/id_rsa_key1`
if [ -z "$PASSWORD" ]; then
    echo "Password not set"
    exit 1
fi

echo "Password: $PASSWORD"

#Now connect via RDP on $FLOAT_IP with creedentials Admin and $PASSWORD
#This will be automated with WinRM ASAP

#Check hostname
#hostname == $VM_NAME

read

# Check VirtIO drivers
#(Get-NetAdapter).DriverDescription == "Red Hat VirtIO Ethernet Adapter"

read

# Check partition extension
#diskpart
#list disk
# Output must contain: 0 B in the "Free" column

read

#Check attach volume
VOLUME_ID=`cinder create 1  | awk '{if (NR == 10) {print $4}}'`

VOLUME_STATUS=`cinder show $VOLUME_ID | awk '{if (NR == 19) {print $4}}'`
while [ "$VOLUME_STATUS" != "available" ]; do
    sleep 3
    VOLUME_STATUS=`cinder show $VOLUME_ID | awk '{if (NR == 19) {print $4}}'`
done

nova volume-attach $VM_ID $VOLUME_ID /dev/sdb

#diskpart
#select disk 1
#attributes disk clear readonly
#online disk
#create partition primary 

read

# Check detach volume
nova volume-detach $VM_ID $VOLUME_ID
cinder delete $VOLUME_ID

#diskpart
#list disk
#Output must contain only disk 0

read

# Done
nova delete $VM_ID

