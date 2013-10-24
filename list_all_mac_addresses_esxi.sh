#!/bin/sh

for lines in `vim-cmd vmsvc/getallvms | awk '{print $1":" $2}' | grep -v Vmid`; do
    id=$(echo $lines | awk -F: '{print $1}')
    name=$(echo $lines | awk -F: '{print $2}')
    mac=$(vim-cmd vmsvc/device.getdevices $id | grep macAddress)
    echo $id $name $mac
done


