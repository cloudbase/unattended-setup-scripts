#!/bin/sh
set -e

echoerr() { echo "$@" 1>&2; }

if [ $# -ne 1 ]; then
    echo "Usage: $0 <vm_name>"
    exit 1
fi

VM_NAME=$1

VMID=`/bin/vim-cmd vmsvc/getallvms | awk -vvmname="$VM_NAME" '{if ($2 == vmname) print $1}'`

if [ -z "$VMID" ]; then
    echoerr "VM not found: $VM_NAME"
    exit 1
fi

echo $VMID

