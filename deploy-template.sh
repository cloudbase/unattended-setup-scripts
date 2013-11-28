#!/bin/bash
set -e

if [ $# -lt 3 ]; then
    echo "Usage: $0 <esxi_user> <esxi_host> <template> [<scripts_datastore>] [<template_datastore>] [<datastore>] [<resource_pool_name>] [<vm_name>] [<ram>] [<network>]"
    exit 1
fi

ESXI_USER=$1
ESXI_HOST=$2
TEMPLATE_NAME=$3
SCRIPTS_DATASTORE=${4:-ssd1}
TEMPLATE_DATASTORE=${5:-ssd1}
DATASTORE=${6:-ssd1}
POOL_NAME=${7:-$ESXI_USER}
VM_NAME=${8:-$TEMPLATE_NAME-$RANDOM}
RAM=${9:-1024}
NETWORK=${10:-"VM Network"}

NET_ADAPTER_TYPE=vmxnet3

ESXI_BASEDIR=/vmfs/volumes/$SCRIPTS_DATASTORE/unattended-scripts
TEMPLATE_BASEDIR=/vmfs/volumes/$TEMPLATE_DATASTORE/$TEMPLATE_NAME

TEMPLATE_VMX_FILE=$TEMPLATE_BASEDIR/$TEMPLATE_NAME.vmx
GUEST_OS=`ssh $ESXI_USER@$ESXI_HOST "sed -rn 's/guestOS = \"(.+)\"/\1/p'" $TEMPLATE_VMX_FILE`

TEMPLATE_VMDK=$TEMPLATE_BASEDIR/$TEMPLATE_NAME.vmdk

ssh $ESXI_USER@$ESXI_HOST $ESXI_BASEDIR/create-esxi-vm.sh $DATASTORE $GUEST_OS $VM_NAME $POOL_NAME $RAM 2 2 - $TEMPLATE_VMDK - - - false $NET_ADAPTER_TYPE true \""$NETWORK"\"

echo "VM $VM_NAME started"

