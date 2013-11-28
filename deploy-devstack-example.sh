#!/bin/bash
set -e

if [ $# -lt 5 ]; then
    echo "Usage: $0 <esxi_user> <esxi_host> <scripts_datastore> <templates_datastore> <datastore> [<use_linked_vmdks>]"
    exit 1
fi

ESXI_USER=$1
ESXI_HOST=$2
SCRIPTS_DATASTORE=$3
TEMPLATES_DATASTORE=$4
DATASTORE=$5
VMDK_OPTION=$6

DEVSTACK_NAME=devstack-test-$RANDOM

ESXI_PUBLIC_SWITCH=vSwitch0
ESXI_PUBLIC_VMNIC=vmnic0

LINUX_TEMPLATE_VMDK=/vmfs/volumes/$TEMPLATES_DATASTORE/ubuntu-12.04-server-template-100G/ubuntu-12.04-server-template-100G.vmdk
HYPERV_TEMPLATE_VMDK=/vmfs/volumes/$TEMPLATES_DATASTORE/hyperv-2012-r2-template-100G/hyperv-2012-r2-template-100G.vmdk

if [ "$VMDK_OPTION" == "use_linked_vmdks" ]; then
    LINUX_TEMPLATE_VMDK=${LINUX_TEMPLATE_VMDK%%.vmdk}-000001.vmdk
    HYPERV_TEMPLATE_VMDK=${HYPERV_TEMPLATE_VMDK%%.vmdk}-000001.vmdk    
fi

BASEDIR=$(dirname $0)

echo "Deploying DevStack: $DEVSTACK_NAME"

$BASEDIR/deploy-devstack.sh $ESXI_USER $ESXI_HOST "$SCRIPTS_DATASTORE" "$DATASTORE" "$DEVSTACK_NAME" "$ESXI_PUBLIC_SWITCH" $ESXI_PUBLIC_VMNIC "$LINUX_TEMPLATE_VMDK" "$HYPERV_TEMPLATE_VMDK"

