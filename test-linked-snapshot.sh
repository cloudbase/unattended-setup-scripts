#!/bin/sh
set -e

DATASTORE=datastore1
POOL_NAME=apilotti
VM_NAME=centos_test4
VM_NAME2=centos_test5

ssh apilotti@10.7.2.2 /vmfs/volumes/datastore1/unattended-scripts/delete-esxi-vm.sh "$VM_NAME2" $DATASTORE
ssh apilotti@10.7.2.2 /vmfs/volumes/datastore1/unattended-scripts/delete-esxi-vm.sh "$VM_NAME" $DATASTORE

ssh apilotti@10.7.2.2 /vmfs/volumes/datastore1/unattended-scripts/create-esxi-vm.sh $DATASTORE rhel6-64 "$VM_NAME" $POOL_NAME 1024 2 2 - /vmfs/volumes/datastore1/centos-6.4-template/centos-6.4-template.vmdk - - - false "VM Network"
ssh apilotti@10.7.2.2 /vmfs/volumes/datastore1/unattended-scripts/create-esxi-vm-snapshot.sh "$VM_NAME" template false

ssh apilotti@10.7.2.2 /vmfs/volumes/datastore1/unattended-scripts/create-esxi-vm.sh $DATASTORE rhel6-64 "$VM_NAME2" $POOL_NAME 1024 2 2 - /vmfs/volumes/datastore1/$VM_NAME/$VM_NAME-000001.vmdk - - - false "VM Network"
echo "Sleeping..."
sleep 20
echo "Powering on $VM_NAME2"
ssh apilotti@10.7.2.2 /vmfs/volumes/datastore1/unattended-scripts/power-on-esxi-vm.sh "$VM_NAME2"

