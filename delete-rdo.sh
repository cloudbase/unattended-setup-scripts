#!/bin/sh
set -e

if [ $# -ne 2 ]; then
    echo "Usage: $0 <datastore> <rdo_name>"
    exit 1
fi

DATASTORE=$1
RDO_NAME=$2

MGMT_NETWORK="$RDO_NAME"_mgmt
DATA_NETWORK="$RDO_NAME"_data
EXT_NETWORK="$RDO_NAME"_external

POOL_NAME=$RDO_NAME

CONTROLLER_VM_NAME="$RDO_NAME"_controller
NETWORK_VM_NAME="$RDO_NAME"_network
QEMU_COMPUTE_VM_NAME="$RDO_NAME"_compute_qemu
HYPERV_COMPUTE_VM_NAME="$RDO_NAME"_compute_hyperv

BASEDIR=$(dirname $0)

$BASEDIR/delete-esxi-vm.sh "$CONTROLLER_VM_NAME" "$DATASTORE"
$BASEDIR/delete-esxi-vm.sh "$NETWORK_VM_NAME" "$DATASTORE"
$BASEDIR/delete-esxi-vm.sh "$QEMU_COMPUTE_VM_NAME" "$DATASTORE"
$BASEDIR/delete-esxi-vm.sh "$HYPERV_COMPUTE_VM_NAME" "$DATASTORE"

$BASEDIR/delete-esxi-resource-pool.sh "$POOL_NAME"

