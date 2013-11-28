#!/bin/bash
set -e

if [ $# -lt 6 ]; then
    echo "Usage: $0 <esxi_user> <esxi_host> <scripts_datastore> <templates_datastore> <datastore> <openstack_release> [<use_linked_vmdks>]"
    exit 1
fi

ESXI_USER=$1
ESXI_HOST=$2
SCRIPTS_DATASTORE=$3
TEMPLATES_DATASTORE=$4
DATASTORE=$5
OPENSTACK_RELEASE=$6
VMDK_OPTION=$7

RDO_NAME=rdo-test-$RANDOM

ESXI_PUBLIC_SWITCH=vSwitch0
ESXI_PUBLIC_VMNIC=vmnic0

LINUX_TEMPLATE_VMDK=/vmfs/volumes/$TEMPLATES_DATASTORE/centos-6.4-template-100G/centos-6.4-template-100G.vmdk

if [ "$OPENSTACK_RELEASE" == "grizzly" ]; then
    HYPERV_TEMPLATE_VMDK=/vmfs/volumes/$TEMPLATES_DATASTORE/hyperv-2012-template-100G/hyperv-2012-template-100G.vmdk
else
    HYPERV_TEMPLATE_VMDK=/vmfs/volumes/$TEMPLATES_DATASTORE/hyperv-2012-r2-template-100G/hyperv-2012-r2-template-100G.vmdk
fi

if [ "$VMDK_OPTION" == "use_linked_vmdks" ]; then
    LINUX_TEMPLATE_VMDK=${LINUX_TEMPLATE_VMDK%%.vmdk}-000001.vmdk
    HYPERV_TEMPLATE_VMDK=${HYPERV_TEMPLATE_VMDK%%.vmdk}-000001.vmdk    
fi

BASEDIR=$(dirname $0)

echo "Deploying RDO: $RDO_NAME"

$BASEDIR/deploy-rdo.sh $ESXI_USER $ESXI_HOST "$SCRIPTS_DATASTORE" "$DATASTORE" $OPENSTACK_RELEASE "$RDO_NAME" "$ESXI_PUBLIC_SWITCH" $ESXI_PUBLIC_VMNIC "$LINUX_TEMPLATE_VMDK" "$HYPERV_TEMPLATE_VMDK"

