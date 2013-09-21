DATASTORE=$1
ISO_PATH=$6
VM_NAME=$3
FLOPPY_PATH=$8
GUEST_OS=$2
RAM=$4
VMDK_SIZE=$5
VMWARE_TOOLS_ISO=$7
VM_NETWORK=$9

DATASTORE_PATH=/vmfs/volumes/$DATASTORE

VMID=`/bin/vim-cmd vmsvc/getallvms | awk -vvmname="$VM_NAME" '{if ($2 == vmname) print $1}'`
if [[ -n "$VMID" ]]; then
    OFF=`vim-cmd vmsvc/power.getstate $VMID | grep "Powered off"`
    if [[ -z "$OFF" ]]; then
        /bin/vim-cmd vmsvc/power.off $VMID
    fi
    /bin/vim-cmd vmsvc/unregister $VMID
fi

rm -rf $DATASTORE_PATH/$VM_NAME
./create-esxi-vm.sh $DATASTORE $GUEST_OS $VM_NAME $RAM 2 2 $VMDK_SIZE - $ISO_PATH $VMWARE_TOOLS_ISO $FLOPPY_PATH true "$VM_NETWORK"

