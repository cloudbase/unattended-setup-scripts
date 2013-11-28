#!/bin/bash
set -e

if [ $# -ne 3 ]; then
    echo "Usage: $0 <esxi_user> <esxi_host> <scripts_datastore>"
    exit 1
fi

ESXI_USER=$1
ESXI_HOST=$2
SCRIPTS_DATASTORE=$3

ESXI_SCRIPTS_DIR=/vmfs/volumes/$SCRIPTS_DATASTORE/unattended-scripts/templates

TEMPLATE_SCRIPTS[0]="create-hyperv-2012-r2-vm-template.sh"
TEMPLATE_SCRIPTS[1]="create-hyperv-2012-vm-template.sh"
TEMPLATE_SCRIPTS[2]="create-hyperv-2012-cn-vm-template.sh"
TEMPLATE_SCRIPTS[3]="create-windows-8.1-enterprise-vm-template.sh"
TEMPLATE_SCRIPTS[4]="create-centos-64-vm-template.sh"
TEMPLATE_SCRIPTS[5]="create-centos-64-cloudinit-vm-template.sh"
TEMPLATE_SCRIPTS[6]="create-ubuntu-1204-server-vm-template.sh"


for TEMPLATE_SCRIPT in "${TEMPLATE_SCRIPTS[@]}"; do
    ssh $ESXI_USER@$ESXI_HOST "$ESXI_SCRIPTS_DIR/$TEMPLATE_SCRIPT" > /dev/null &
done

wait

