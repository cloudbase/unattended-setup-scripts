#!/bin/sh
set -e

if [ $# -ne 3 ]; then
    echo "Usage: $0 <vm_name> <user_name> <role>"
    exit 1
fi

VM_NAME=$1
USER_NAME=$2
ROLE_NAME=$3

BASEDIR=$(dirname $0)

VMID=`$BASEDIR/get-esxi-vm-id.sh "$VM_NAME"` 
vim-cmd vimsvc/auth/entity_permission_add vim.VirtualMachine:$VMID $USER_NAME false $ROLE_NAME true

