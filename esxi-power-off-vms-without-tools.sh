#!/bin/sh
set -e

for VMID in `vim-cmd vmsvc/getallvms | awk '{ if (NR > 1) print $1 }'`
do
    vim-cmd vmsvc/power.getstate $VMID

    ON=`vim-cmd vmsvc/power.getstate $VMID | grep "Powered on" || EXIT=$?`
    if [[ -n "$ON" ]]; then
        HB=`vim-cmd vmsvc/get.guestheartbeatStatus $VMID`
        if [ "$HB" != "green" ]; then
            echo "Powering off VM: $VMID"
            /bin/vim-cmd vmsvc/power.off $VMID
        fi
    fi
done
