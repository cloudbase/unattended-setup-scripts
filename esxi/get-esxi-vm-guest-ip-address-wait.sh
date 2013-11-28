#!/bin/sh
set -e

choerr() { echo "$@" 1>&2; }

if [ $# -ne 5 ]; then
    echo "Usage: $0 <vm_name> <network_name> <ipv4_only> <interval_seconds> <max_wait_seconds>"
    exit 1
fi

VM_NAME=$1
NETWORK_NAME=$2
IPV4_ONLY=$3
INTERVAL=$4
MAX_WAIT=$5

BASEDIR=$(dirname $0)

COUNTER=0
while [ $COUNTER -lt $MAX_WAIT ]; do
    IP=`$BASEDIR/get-esxi-vm-guest-ip-address.sh "$VM_NAME" "$NETWORK_NAME" $IPV4_ONLY`                        
    if [ -n "$IP" ]; then
        echo $IP | sed 's/\ /\n/g'
        exit 0
    fi
    sleep $INTERVAL
    let COUNTER=COUNTER+$INTERVAL
done

echoerr "It was not possible to retrieve the guest IP addresses for VM $VM_NAME in $MAX_WAIT seconds"
exit 1

