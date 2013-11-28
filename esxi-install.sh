#!/bin/bash
set -e

if [ $# -ne 3 ]; then
    echo "Usage: $0 <esxi_user> <esxi_host> <datastore>"
    exit 1
fi

ESXI_USER=$1
ESXI_HOST=$2
DATASTORE=$3

ESXI_BASEDIR=/vmfs/volumes/$DATASTORE/unattended-scripts

BASEDIR=$(dirname $0)

ssh $ESXI_USER@$ESXI_HOST "if [ -d $ESXI_BASEDIR ]; then rm -rf $ESXI_BASEDIR; fi && mkdir -p $ESXI_BASEDIR"
scp -r $BASEDIR/esxi/* $ESXI_USER@$ESXI_HOST:$ESXI_BASEDIR/

