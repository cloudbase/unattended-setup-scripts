#!/bin/sh
set -e

if [ $# -ne 11 ]; then
    echo "Usage: $0 <datastore> <iso_path> <vm_name> <floppy_path> <guest_os> <ram> <vmdk_size> <vmware_tools_iso> <vm_network> <wait> <snapshot_vm>"
    exit 1
fi

DATASTORE=$1
ISO_PATH=$6
VM_NAME=$3
FLOPPY_PATH=$8
GUEST_OS=$2
RAM=$4
VMDK_SIZE=$5
VMWARE_TOOLS_ISO=$7
VM_NETWORK=$9
WAIT=$10
SNAPSHOT_VM=$11

WAIT_INTERVAL=30
MAX_WAIT=14400

SNAPSHOT_NAME=template

POOL_NAME=templates

NET_ADAPTER_TYPE=e1000e

DATASTORE_PATH=/vmfs/volumes/$DATASTORE

BASEDIR=$(dirname $0)
ESXI_SCRIPTS_DIR="$BASEDIR/.."

$ESXI_SCRIPTS_DIR/delete-esxi-vm.sh "$VM_NAME" "$DATASTORE"

echo "Creating VM"
$ESXI_SCRIPTS_DIR/create-esxi-vm.sh $DATASTORE $GUEST_OS "$VM_NAME" $POOL_NAME $RAM 2 2 $VMDK_SIZE - $ISO_PATH $VMWARE_TOOLS_ISO $FLOPPY_PATH false $NET_ADAPTER_TYPE true "$VM_NETWORK"

# Set permission to ReadOnly for everybody except the current user
$ESXI_SCRIPTS_DIR/set-esxi-vm-permission-all-users.sh "$VM_NAME" ReadOnly "$USER"

if [ "$WAIT" == "true" ] || [ "$SNAPSHOT_VM" == "true" ]; then
    echo "Waiting for the VM setup to complete..."
    $ESXI_SCRIPTS_DIR/wait-for-esxi-vm-state.sh "$VM_NAME" off $WAIT_INTERVAL $MAX_WAIT

    if [ "$SNAPSHOT_VM" == "true" ]; then
        echo "Creating VM snapshot" 
        $ESXI_SCRIPTS_DIR/create-esxi-vm-snapshot.sh "$VM_NAME" "$SNAPSHOT_NAME" false   
    fi
fi

