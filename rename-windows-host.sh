#!/bin/bash

if [ $# -ne 4 ]; then
    echo "Usage: $0 <host> <user> <password> <new_host_name>"
    exit 1
fi

HOST=$1
USERNAME=$2
PASSWORD=$3
NEW_HOST_NAME=$4

BASEDIR=$(dirname $0)

$BASEDIR/wsmancmd.py -U https://$HOST:5986/wsman -u $USERNAME -p $PASSWORD 'powershell -NonInteractive -Command "if ([System.Net.Dns]::GetHostName() -ne \"'$NEW_HOST_NAME'\") { Rename-Computer \"'$NEW_HOST_NAME'\" -Restart -Force }"'

