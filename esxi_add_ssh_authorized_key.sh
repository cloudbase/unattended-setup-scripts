#!/bin/bash

# Add your user's pub key to an ESXi host authorized keys
# During the process you'll be prompted for the remote password twice

if [ $# -lt 2 ]; then
    echo "Usage: $0 <username> <esxi_host> [<pub_key_path>]"
    exit 1
fi

USERNAME=$1
ESXI_HOST=$2

if [ $# -eq 3 ]; then
    PUB_KEY=$3
else
    PUB_KEY=~/.ssh/id_rsa.pub
fi

REMOTE_TMP_PUB_KEY=/tmp/ssh_pub_$USERNAME.pub

scp $PUB_KEY $USERNAME@$ESXI_HOST:$REMOTE_TMP_PUB_KEY
ssh $USERNAME@$ESXI_HOST "mkdir -p /etc/ssh/keys-$USERNAME && cat $REMOTE_TMP_PUB_KEY >> /etc/ssh/keys-$USERNAME/authorized_keys && rm $REMOTE_TMP_PUB_KEY"

