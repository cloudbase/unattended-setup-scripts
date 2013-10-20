#!/bin/sh
set -e

if [ $# -ne 3 ]; then
    echo "Usage: $0 <datastore> <devstack_name> <esxi_public_switch>"
    exit 1
fi

DATASTORE=$1
DEVSTACK_NAME=$2
EXT_SWITCH=$3

MGMT_NETWORK="$DEVSTACK_NAME"_mgmt
DATA_NETWORK="$DEVSTACK_NAME"_data
EXT_NETWORK="$DEVSTACK_NAME"_external

POOL_NAME=$DEVSTACK_NAME

CONTROLLER_VM_NAME="$DEVSTACK_NAME"-controller
HYPERV_COMPUTE_VM_NAME="$DEVSTACK_NAME"-compute-hyperv

BASEDIR=$(dirname $0)

$BASEDIR/delete-esxi-vm.sh "$CONTROLLER_VM_NAME" "$DATASTORE"
$BASEDIR/delete-esxi-vm.sh "$HYPERV_COMPUTE_VM_NAME" "$DATASTORE"

echo "Removing $POOL_NAME resource pool"
$BASEDIR/delete-esxi-resource-pool.sh "$POOL_NAME"

echo "Removing $MGMT_NETWORK portgroup"
vim-cmd hostsvc/net/portgroup_remove "$EXT_SWITCH" "$MGMT_NETWORK"
echo "Removing $EXT_NETWORK portgroup"
vim-cmd hostsvc/net/portgroup_remove "$EXT_SWITCH" "$EXT_NETWORK"

echo "Removing $DATA_NETWORK portgroup"
vim-cmd hostsvc/net/portgroup_remove "$DATA_NETWORK" "$DATA_NETWORK"
echo "Removing $DATA_NETWORK switch"
vim-cmd hostsvc/net/vswitch_remove "$DATA_NETWORK"

