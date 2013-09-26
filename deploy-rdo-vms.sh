#!/bin/sh
set -e

if [ $# -ne 4 ]; then
    echo "Usage: $0 <datastore> <name> <switch> <nic>"
    exit 1
fi

BASEDIR=$(dirname $0)

DATASTORE=$1
RDO_NAME=$2
EXT_SWITCH=$3
VMNIC=$4

MGMT_NETWORK="$RDO_NAME"_mgmt
DATA_NETWORK="$RDO_NAME"_data
EXT_NETWORK="$RDO_NAME"_external

LINUX_GUEST_OS=rhel6-64
HYPERV_GUEST_OS=winhyperv

LINUX_TEMPLATE=/vmfs/volumes/datastore2/centos-6.4-template/centos-6.4-template.vmdk
HYPERV_TEMPLATE=/vmfs/volumes/datastore2/hyperv-2012-template/hyperv-2012-template.vmdk

CONTROLLER_VM_NAME="$RDO_NAME"_controller
NETWORK_VM_NAME="$RDO_NAME"_network
QEMU_COMPUTE_VM_NAME="$RDO_NAME"_compute_qemu
HYPERV_COMPUTE_VM_NAME="$RDO_NAME"_compute_hyperv

/bin/vim-cmd hostsvc/net/portgroup_add $EXT_SWITCH $EXT_NETWORK
/bin/vim-cmd hostsvc/net/portgroup_set --nicorderpolicy-active=$VMNIC $EXT_SWITCH $EXT_NETWORK

/bin/vim-cmd hostsvc/net/portgroup_add $EXT_SWITCH $MGMT_NETWORK
/bin/vim-cmd hostsvc/net/portgroup_set --nicorderpolicy-active=$VMNIC $EXT_SWITCH $MGMT_NETWORK

$BASEDIR/create-esxi-switch.sh $DATA_NETWORK

$BASEDIR/create-esxi-vm.sh $DATASTORE $LINUX_GUEST_OS $CONTROLLER_VM_NAME 1024 2 2 11G $LINUX_TEMPLATE - - - true "$MGMT_NETWORK"
$BASEDIR/create-esxi-vm.sh $DATASTORE $LINUX_GUEST_OS $NETWORK_VM_NAME 1024 2 2 11G $LINUX_TEMPLATE - - - true "$MGMT_NETWORK" "$DATA_NETWORK" "$EXT_NETWORK"
$BASEDIR/create-esxi-vm.sh $DATASTORE $LINUX_GUEST_OS $QEMU_COMPUTE_VM_NAME 4096 2 2 30G $LINUX_TEMPLATE - - - true "$MGMT_NETWORK" "$DATA_NETWORK"
$BASEDIR/create-esxi-vm.sh $DATASTORE $HYPERV_GUEST_OS $HYPERV_COMPUTE_VM_NAME 4096 2 2 60G $HYPERV_TEMPLATE - - - true "$MGMT_NETWORK" "$DATA_NETWORK" 

