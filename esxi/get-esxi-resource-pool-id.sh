#!/bin/sh

if [ $# -ne 1 ]; then
    echo "Usage: $0 <pool_name>"
    exit 1
fi

POOL_NAME=$1

POOL_ID=`sed -rn 'N; s/\ +<name>'"$POOL_NAME"'<\/name>\n\ +<objID>(.+)<\/objID>/\1/p' /etc/vmware/hostd/pools.xml`
echo $POOL_ID
