#!/bin/sh

if [ $# -ne 1 ]; then
    echo "Usage: $0 <switch_name>"
    exit 1
fi

SWITCH_NAME=$1

vim-cmd hostsvc/net/vswitch_info | sed -rn 's/\ +name\ =\ \"'"$SWITCH_NAME"'\",\ +/true/p'

