#!/bin/sh
set -e

if [ $# -ne 1 ]; then
    echo "Usage: $0 <vm_name>"
    exit 1
fi

VM_NAME=$1

/bin/vim-cmd vmsvc/getallvms | awk -vvmname="$VM_NAME" '{if ($2 == vmname) print $1}'

