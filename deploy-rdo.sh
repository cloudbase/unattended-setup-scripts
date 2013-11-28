#!/bin/bash
set -e

if [ $# -ne 10 ]; then
    echo "Usage: $0 <esxi_user> <esxi_host> <scripts_datastore> <datastore> <openstack_release> <rdo_name> <esxi_public_switch> <esxi_public_vnic> <linux_template_vmdk> <hyperv_template_vmdk>"
    exit 1
fi

ESXI_USER=$1
ESXI_HOST=$2
SCRIPTS_DATASTORE=$3
DATASTORE=$4
OPENSTACK_RELEASE=$5
RDO_NAME=$6
ESXI_PUBLIC_SWITCH=$7
ESXI_PUBLIC_VNIC=$8
LINUX_TEMPLATE_VMDK=$9
HYPERV_TEMPLATE_VMDK=${10}

BASEDIR=$(dirname $0)

. $BASEDIR/utils.sh

case "$OPENSTACK_RELEASE" in
grizzly|havana)
    ;;
*)
    echoerr "Unsupported OpenStack release: $OPENSTACK_RELEASE"
    exit 1
    ;;
esac

ESXI_BASEDIR=/vmfs/volumes/$SCRIPTS_DATASTORE/unattended-scripts
RDO_VM_IPS_FILE=`mktemp -u /tmp/rdo_ips.XXXXXX`

ssh $ESXI_USER@$ESXI_HOST $ESXI_BASEDIR/deploy-rdo-esxi-vms.sh $DATASTORE $RDO_NAME $ESXI_PUBLIC_SWITCH $ESXI_PUBLIC_VNIC "$LINUX_TEMPLATE_VMDK" "$HYPERV_TEMPLATE_VMDK" $RDO_VM_IPS_FILE
read CONTROLLER_VM_NAME CONTROLLER_VM_IP NETWORK_VM_NAME NETWORK_VM_IP QEMU_COMPUTE_VM_NAME QEMU_COMPUTE_VM_IP HYPERV_COMPUTE_VM_NAME HYPERV_COMPUTE_VM_IP <<< `ssh $ESXI_USER@$ESXI_HOST "cat $RDO_VM_IPS_FILE" | perl -n -e'/^(.+)\:(.+)$/ && print "$1\n$2\n"'`

SSH_KEY_FILE=`mktemp -u /tmp/rdo_ssh_key.XXXXXX`
ssh-keygen -q -t rsa -f $SSH_KEY_FILE -N "" -b 4096

$BASEDIR/configure-rdo.sh $OPENSTACK_RELEASE $SSH_KEY_FILE $CONTROLLER_VM_NAME $CONTROLLER_VM_IP $NETWORK_VM_NAME $NETWORK_VM_IP $QEMU_COMPUTE_VM_NAME $QEMU_COMPUTE_VM_IP $HYPERV_COMPUTE_VM_NAME $HYPERV_COMPUTE_VM_IP

