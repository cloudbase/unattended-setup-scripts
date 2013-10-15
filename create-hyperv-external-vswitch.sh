#!/bin/sh

if [ $# -ne 4 ]; then
    echo "Usage: $0 <management_ip> <username> <password> <switch_name>"
    exit 1
fi

# This is the IP of the interface that will NOT be configured
MGMT_IP=$1
HYPERV_USER=$2
HYPERV_PASSWORD=$3
SWITCH_NAME=$4

BASEDIR=$(dirname $0)

$BASEDIR/wsmancmd.py -U https://$MGMT_IP:5986/wsman -u "$HYPERV_USER" -p "$HYPERV_PASSWORD" powershell -NonInteractive -Command '"if (!(Get-VMSwitch | where {$_.Name -eq \"'$SWITCH_NAME'\"})) {New-VMSwitch -Name \"'$SWITCH_NAME'\" -AllowManagementOS $false -InterfaceAlias (Get-NetAdapter | where {$_.IfIndex -ne ((Get-NetIPAddress -IPAddress \"'$MGMT_IP'\").InterfaceIndex)}).Name}"'

