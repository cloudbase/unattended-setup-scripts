#!/bin/bash
set -e

RDO_NAME=rdo_test_$RANDOM
ESXI_HOST=10.7.2.2
ESXI_USER=root

DATASTORE=datastore1
ESXI_PUBLIC_SWITCH=vSwitch0
ESXI_PUBLIC_VMNIC=vmnic0

LINUX_TEMPLATE_VMDK=/vmfs/volumes/datastore1/centos-6.4-template-40G/centos-6.4-template-40G-000001.vmdk
HYPERV_TEMPLATE_VMDK=/vmfs/volumes/datastore1/hyperv-2012-template-80G/hyperv-2012-template-80G-000001.vmdk

BASEDIR=$(dirname $0)

echo "Deploying RDO: $RDO_NAME"

$BASEDIR/deploy-rdo.sh $ESXI_USER $ESXI_HOST "$DATASTORE" "$RDO_NAME" "$ESXI_PUBLIC_SWITCH" $ESXI_PUBLIC_VMNIC "$LINUX_TEMPLATE_VMDK" "$HYPERV_TEMPLATE_VMDK"

