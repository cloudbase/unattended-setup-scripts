#!/bin/sh
set -e

echoerr() { echo "$@" 1>&2; }

if [ $# -lt 6 ]; then
    echo "Usage: $0 <datastore> <name> <switch> <nic> <linux_template_vmdk> <hyperv_template_vmdk> [<guest_ips_file_name>]"
    exit 1
fi

BASEDIR=$(dirname $0)

DATASTORE=$1
RDO_NAME=$2
EXT_SWITCH=$3
VMNIC=$4
LINUX_TEMPLATE_VMDK=$5
HYPERV_TEMPLATE_VMDK=$6
GUEST_IPS_FILENAME=$7

MGMT_NETWORK="$RDO_NAME"_mgmt
DATA_NETWORK="$RDO_NAME"_data
EXT_NETWORK="$RDO_NAME"_external

POOL_NAME=$RDO_NAME

LINUX_GUEST_OS=rhel6-64
HYPERV_GUEST_OS=winhyperv

CONTROLLER_VM_NAME="$RDO_NAME"-controller
NETWORK_VM_NAME="$RDO_NAME"-network
QEMU_COMPUTE_VM_NAME="$RDO_NAME"-compute-qemu
HYPERV_COMPUTE_VM_NAME="$RDO_NAME"-compute-hyperv

CONTROLLER_VM_RAM=2048
NETWORK_VM_RAM=1024
QEMU_COMPUTE_VM_RAM=4096
HYPERV_COMPUTE_VM_RAM=4096

NET_ADAPTER_TYPE=vmxnet3

if [ ! -f "$LINUX_TEMPLATE_VMDK" ]; then
   echoerr "Linux template VMDK not found: $LINUX_TEMPLATE_VMDK"
   exit 1
fi

if [ ! -f "$HYPERV_TEMPLATE_VMDK" ]; then
   echoerr "Hyper-V template VMDK not found: $HYPERV_TEMPLATE_VMDK"
   exit 1
fi

POOL_ID=`$BASEDIR/get-esxi-resource-pool-id.sh $POOL_NAME`
if [ -z $POOL_ID ]; then
    $BASEDIR/create-esxi-resource-pool.sh $POOL_NAME > /dev/null
fi

PORTGROUP_EXISTS=`$BASEDIR/check-esxi-portgroup-exists.sh "$EXT_NETWORK"`
if [ -z "$PORTGROUP_EXISTS" ]; then
    /bin/vim-cmd hostsvc/net/portgroup_add "$EXT_SWITCH" "$EXT_NETWORK"
fi
/bin/vim-cmd hostsvc/net/portgroup_set --nicorderpolicy-active=$VMNIC "$EXT_SWITCH" "$EXT_NETWORK"

PORTGROUP_EXISTS=`$BASEDIR/check-esxi-portgroup-exists.sh "$MGMT_NETWORK"`
if [ -z "$PORTGROUP_EXISTS" ]; then
    /bin/vim-cmd hostsvc/net/portgroup_add "$EXT_SWITCH" "$MGMT_NETWORK"
fi
/bin/vim-cmd hostsvc/net/portgroup_set --nicorderpolicy-active=$VMNIC "$EXT_SWITCH" "$MGMT_NETWORK"

SWITCH_EXISTS=`$BASEDIR/check-esxi-switch-exists.sh "$DATA_NETWORK"`
if [ -z "$SWITCH_EXISTS" ]; then
    $BASEDIR/create-esxi-switch.sh "$DATA_NETWORK"
fi

$BASEDIR/delete-esxi-vm.sh "$CONTROLLER_VM_NAME" $DATASTORE
$BASEDIR/delete-esxi-vm.sh "$NETWORK_VM_NAME" $DATASTORE
$BASEDIR/delete-esxi-vm.sh "$QEMU_COMPUTE_VM_NAME" $DATASTORE
$BASEDIR/delete-esxi-vm.sh "$HYPERV_COMPUTE_VM_NAME" $DATASTORE

$BASEDIR/create-esxi-vm.sh $DATASTORE $LINUX_GUEST_OS $CONTROLLER_VM_NAME $POOL_NAME $CONTROLLER_VM_RAM 4 2 - $LINUX_TEMPLATE_VMDK - - - false $NET_ADAPTER_TYPE true "$MGMT_NETWORK"
$BASEDIR/create-esxi-vm.sh $DATASTORE $LINUX_GUEST_OS $NETWORK_VM_NAME $POOL_NAME $NETWORK_VM_RAM 4 2 - $LINUX_TEMPLATE_VMDK - - - false $NET_ADAPTER_TYPE true "$MGMT_NETWORK" "$DATA_NETWORK" "$EXT_NETWORK"
$BASEDIR/create-esxi-vm.sh $DATASTORE $LINUX_GUEST_OS $QEMU_COMPUTE_VM_NAME $POOL_NAME $QEMU_COMPUTE_VM_RAM 4 2 - $LINUX_TEMPLATE_VMDK - - - true $NET_ADAPTER_TYPE true "$MGMT_NETWORK" "$DATA_NETWORK"
$BASEDIR/create-esxi-vm.sh $DATASTORE $HYPERV_GUEST_OS $HYPERV_COMPUTE_VM_NAME $POOL_NAME $HYPERV_COMPUTE_VM_RAM 4 2 - $HYPERV_TEMPLATE_VMDK - - - false $NET_ADAPTER_TYPE true "$MGMT_NETWORK" "$DATA_NETWORK"

LINUX_TEMPLATE_PARENT_FILE_HINT=`grep parentFileNameHint "$LINUX_TEMPLATE_VMDK" || true`
HYPERV_TEMPLATE_PARENT_FILE_HINT=`grep parentFileNameHint "$HYPERV_TEMPLATE_VMDK" || true`

if [ -n "$LINUX_TEMPLATE_PARENT_FILE_HINT" ] || [ -n "$HYPERV_TEMPLATE_PARENT_FILE_HINT" ]; then
    # The sleep is necessary as ESXi deletes the parent file if the VM is booted straight after being created
    # this requires additional investigation
    sleep 20

    echo "Powering on $CONTROLLER_VM_NAME"
    $BASEDIR/power-on-esxi-vm.sh "$CONTROLLER_VM_NAME" > /dev/null
    echo "Powering on $NETWORK_VM_NAME"
    $BASEDIR/power-on-esxi-vm.sh "$NETWORK_VM_NAME" > /dev/null
    echo "Powering on $QEMU_COMPUTE_VM_NAME"
    $BASEDIR/power-on-esxi-vm.sh "$QEMU_COMPUTE_VM_NAME" > /dev/null
    echo "Powering on $HYPERV_COMPUTE_VM_NAME"
    $BASEDIR/power-on-esxi-vm.sh "$HYPERV_COMPUTE_VM_NAME" > /dev/null
fi

# So far so good. Get the VM ips

echo "Waiting for guest IPs..."

INTERVAL=5
MAX_WAIT=600

CONTROLLER_VM_IP=`$BASEDIR/get-esxi-vm-guest-ip-address-wait.sh "$CONTROLLER_VM_NAME" "$MGMT_NETWORK" true $INTERVAL $MAX_WAIT`
echo "$CONTROLLER_VM_NAME":"$CONTROLLER_VM_IP"
NETWORK_VM_IP=`$BASEDIR/get-esxi-vm-guest-ip-address-wait.sh "$NETWORK_VM_NAME" "$MGMT_NETWORK" true $INTERVAL $MAX_WAIT`
echo "$NETWORK_VM_NAME":"$NETWORK_VM_IP"
QEMU_COMPUTE_VM_IP=`$BASEDIR/get-esxi-vm-guest-ip-address-wait.sh "$QEMU_COMPUTE_VM_NAME" "$MGMT_NETWORK" true $INTERVAL $MAX_WAIT`
echo "$QEMU_COMPUTE_VM_NAME":"$QEMU_COMPUTE_VM_IP"
HYPERV_COMPUTE_VM_IP=`$BASEDIR/get-esxi-vm-guest-ip-address-wait.sh "$HYPERV_COMPUTE_VM_NAME" "$MGMT_NETWORK" true $INTERVAL $MAX_WAIT`
echo "$HYPERV_COMPUTE_VM_NAME":"$HYPERV_COMPUTE_VM_IP"

if [ -n "$GUEST_IPS_FILENAME" ]; then
    echo "$CONTROLLER_VM_NAME":"$CONTROLLER_VM_IP" > "$GUEST_IPS_FILENAME"
    echo "$NETWORK_VM_NAME":"$NETWORK_VM_IP" >> "$GUEST_IPS_FILENAME"
    echo "$QEMU_COMPUTE_VM_NAME":"$QEMU_COMPUTE_VM_IP" >> "$GUEST_IPS_FILENAME"
    echo "$HYPERV_COMPUTE_VM_NAME":"$HYPERV_COMPUTE_VM_IP" >> "$GUEST_IPS_FILENAME"
fi
