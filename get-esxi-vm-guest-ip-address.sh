#!/bin/sh
set -e

if [ $# -ne 3 ]; then
    echo "Usage: $0 <vm_name> <network_name> <ipv4_only>"
    exit 1
fi

VM_NAME=$1
NETWORK_NAME=$2
IPV4_ONLY=$3

BASEDIR=$(dirname $0)

VMID=`$BASEDIR/get-esxi-vm-id.sh "$VM_NAME"`
IPS=`vim-cmd vmsvc/get.guest $VMID | sed -rn '/network = "'"$NETWORK_NAME"'",/{N;N;N;s/network = "'"$NETWORK_NAME"'",\ +\n\ +ipAddress = \(string\) \[\n\ +"([a-f0-9:\.]+)"/\0/p}' | sed -rn 's/\ +"([a-f0-9\:\.]+)"(,)?/\1/p'`

if [ "$IPV4_ONLY" == "true" ]; then
    IPS=`echo $IPS | sed 's/\ /\n/g' | sed -rn 's/([0-9]+\.[0-9]+\.[0-9]+\.[0-9])/\1/p'`
fi
echo $IPS | sed 's/\ /\n/g'

