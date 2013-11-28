#!/bin/bash
set -e

if [ $# -ne 9 ]; then
    echo "Usage: $0 <esxi_user> <esxi_host> <scripts_datastore> <datastore> <name> <esxi_public_switch> <esxi_public_vnic> <linux_template_vmdk> <hyperv_template_vmdk>"
    exit 1
fi

ESXI_USER=$1
ESXI_HOST=$2
SCRIPTS_DATASTORE=$3
DATASTORE=$4
DEVSTACK_NAME=$5
ESXI_PUBLIC_SWITCH=$6
ESXI_PUBLIC_VNIC=$7
LINUX_TEMPLATE_VMDK=$8
HYPERV_TEMPLATE_VMDK=$9

ESXI_BASEDIR=/vmfs/volumes/$SCRIPTS_DATASTORE/unattended-scripts
VM_IPS_FILE=`mktemp -u /tmp/devstack_ips.XXXXXX`

BASEDIR=$(dirname $0)

ssh $ESXI_USER@$ESXI_HOST $ESXI_BASEDIR/deploy-devstack-esxi-vms.sh $DATASTORE $DEVSTACK_NAME $ESXI_PUBLIC_SWITCH $ESXI_PUBLIC_VNIC "$LINUX_TEMPLATE_VMDK" "$HYPERV_TEMPLATE_VMDK" $VM_IPS_FILE
read CONTROLLER_VM_NAME CONTROLLER_VM_IP HYPERV_COMPUTE_VM_NAME HYPERV_COMPUTE_VM_IP <<< `ssh $ESXI_USER@$ESXI_HOST "cat $VM_IPS_FILE" | perl -n -e'/^(.+)\:(.+)$/ && print "$1\n$2\n"'`

SSH_KEY_FILE=`mktemp -u /tmp/devstack_ssh_key.XXXXXX`
ssh-keygen -q -t rsa -f $SSH_KEY_FILE -N "" -b 4096

$BASEDIR/configure-devstack.sh $SSH_KEY_FILE $CONTROLLER_VM_NAME $CONTROLLER_VM_IP $HYPERV_COMPUTE_VM_NAME $HYPERV_COMPUTE_VM_IP

