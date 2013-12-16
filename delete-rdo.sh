#!/bin/bash
set -e

if [ $# -lt 5 ]; then
    echo "Usage: $0 <esxi_user> <esxi_host> <scripts_datastore> <datastore> <rdo_name> [<esxi_public_switch>]"
    exit 1
fi

ESXI_USER=$1
ESXI_HOST=$2
SCRIPTS_DATASTORE=$3
DATASTORE=$4
RDO_NAME=$5
ESXI_SWITCH=${6:-vSwitch0}

ESXI_SCRIPTS_DIR=/vmfs/volumes/$SCRIPTS_DATASTORE/unattended-scripts/

ssh $ESXI_USER@$ESXI_HOST "$ESXI_SCRIPTS_DIR/delete-rdo.sh" "$DATASTORE" "$RDO_NAME" "$ESXI_SWITCH"

