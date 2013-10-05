#!/bin/sh
set -e

DATASTORE=$1
ISO_PATH=$6
VM_NAME=$3
FLOPPY_PATH=$8
GUEST_OS=$2
RAM=$4
VMDK_SIZE=$5
VMWARE_TOOLS_ISO=$7
VM_NETWORK=$9

POOL_NAME=templates

DATASTORE_PATH=/vmfs/volumes/$DATASTORE

BASEDIR=$(dirname $0)

$BASEDIR/delete-esxi-vm.sh "$VM_NAME" "$DATASTORE"

echo "Creating VM"
$BASEDIR/create-esxi-vm.sh $DATASTORE $GUEST_OS "$VM_NAME" $POOL_NAME $RAM 2 2 $VMDK_SIZE - $ISO_PATH $VMWARE_TOOLS_ISO $FLOPPY_PATH true "$VM_NETWORK"

# Set permission to ReadOnly for everybody except the current user
$BASEDIR/set-esxi-vm-permission-all-users.sh "$VM_NAME" ReadOnly "$USER"

