#!/bin/sh

if [ $# -ne 1 ]; then
    echo "Usage: $0 <switch_name>"
    exit 1
fi

SWITCH_NAME=$1

/bin/vim-cmd hostsvc/net/vswitch_add $SWITCH_NAME
/bin/vim-cmd hostsvc/net/vswitch_setpolicy --securepolicy-promisc=true $SWITCH_NAME
/bin/vim-cmd hostsvc/net/portgroup_add $SWITCH_NAME $SWITCH_NAME

