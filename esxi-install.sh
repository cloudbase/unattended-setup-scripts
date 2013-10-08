#!/bin/bash
set -e

if [ $# -ne 2 ]; then
    echo "Usage: $0 <esxi_user> <esxi_host>"
    exit 1
fi

ESXI_USER=$1
ESXI_HOST=$2

ESXI_BASEDIR=/vmfs/volumes/datastore1/unattended-scripts

BASEDIR=$(dirname $0)

ssh $ESXI_USER@$ESXI_HOST "mkdir -p $ESXI_BASEDIR"
scp $BASEDIR/* $ESXI_USER@$ESXI_HOST:$ESXI_BASEDIR/

