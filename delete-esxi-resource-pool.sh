#!/bin/sh
set -e

echoerr() { echo "$@" 1>&2; }

if [ $# -ne 1 ]; then
    echo "Usage: $0 <pool_name>"
    exit 1
fi

POOL_NAME=$1

BASEDIR=$(dirname $0)

POOL_ID=`$BASEDIR/get-esxi-resource-pool-id.sh $POOL_NAME`
if [ -z "$POOL_ID" ]; then
    echoerr "Resource pool not found: $POOL_NAME"
    exit 1
fi

vim-cmd hostsvc/rsrc/destroy $POOL_ID

