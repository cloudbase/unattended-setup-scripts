#!/bin/sh
set -e

if [ $# -ne 3 ]; then
    echo "Usage: $0 <vm_name> <snapshot_name> <include_memory>"
    exit 1
fi

VM_NAME=$1
SNAPSHOT_NAME=$2
INCLUDE_MEMORY=$3

VMID=`/bin/vim-cmd vmsvc/getallvms | awk -vvmname="$VM_NAME" '{if ($2 == vmname) print $1}'`
if [[ -z "$VMID" ]]; then
    echo "VM $VM_NAME not found"
    exit 1
fi

/bin/vim-cmd vmsvc/snapshot.create $VMID $SNAPSHOT_NAME "" $INCLUDE_MEMORY

