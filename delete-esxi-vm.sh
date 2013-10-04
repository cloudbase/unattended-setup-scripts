#!/bin/sh
set -e

if [ $# -ne 2 ]; then
    echo "Usage: $0 <vm_name> <datastore>"
    exit 1
fi

VM_NAME=$1
DATASTORE=$2

DATASTORE_PATH=/vmfs/volumes/$DATASTORE

VMID=`/bin/vim-cmd vmsvc/getallvms | awk -vvmname="$VM_NAME" '{if ($2 == vmname) print $1}'`
if [[ -n "$VMID" ]]; then
    OFF=`vim-cmd vmsvc/power.getstate $VMID | grep "Powered off" || EXIT=$?`
    if [[ -z "$OFF" ]]; then
        /bin/vim-cmd vmsvc/power.off $VMID
    fi

    /bin/vim-cmd vmsvc/unregister $VMID
fi

rm -rf $DATASTORE_PATH/$VM_NAME

