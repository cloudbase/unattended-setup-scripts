#!/bin/sh
set -e

echoerr() { echo "$@" 1>&2; }

if [ $# -ne 4 ]; then
    echo "Usage: $0 <vm_name> <expected_vm_state> <interval_seconds> <max_wait_seconds>"
    exit 1
fi

VM_NAME=$1
STATE=$2
INTERVAL=$3
MAX_WAIT=$4

BASEDIR=$(dirname $0)

case $STATE in
"on")
    ESXI_STATE="Powered on"
    ;;
"off")
    ESXI_STATE="Powered off"
    ;;
"suspended")
    ESXI_STATE="Suspended"
    ;;
*)
    echoerr "Unknown state: $STATE"
    exit 1
    ;;
esac

VMID=`$BASEDIR/get-esxi-vm-id.sh "$VM_NAME"`

COUNTER=0
while [ $COUNTER -lt $MAX_WAIT ]; do
    EXIT=0
    vim-cmd vmsvc/power.getstate $VMID | grep "$ESXI_STATE" || EXIT=1
    if [ $EXIT -eq 0 ]; then
        exit 0
    fi
    sleep $INTERVAL
    let COUNTER=COUNTER+$INTERVAL
done

echoerr "Max wait interval of $MAX_WAIT seconds exceeded"
exit 1

