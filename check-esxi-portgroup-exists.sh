#!/bin/sh

if [ $# -ne 1 ]; then
    echo "Usage: $0 <portgroup_name>"
    exit 1
fi

PORTGROUP_NAME=$1

vim-cmd hostsvc/net/vswitch_info | sed -rn 's/\ +<vim.host.PortGroup:key-vim.host.PortGroup-'"$PORTGROUP_NAME"'>(,\ +)?/true/p'
