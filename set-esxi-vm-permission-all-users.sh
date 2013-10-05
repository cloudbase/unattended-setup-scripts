#!/bin/sh
set -e

isinlist () {
    for ITEM in `echo $2 | sed -e 's/,/\n/g'`
    do
        if [ "$ITEM" == "$1" ]; then
            return 1
        fi
    done
}

if [ $# -lt 2 ]; then
    echo "Usage: $0 <vm_name> <role> [<excluded_user_names>]"
    exit 1
fi

VM_NAME=$1
EXCLUDED_USER_NAMES=$3
ROLE_NAME=$2

BASEDIR=$(dirname $0)

for USER_NAME in `$BASEDIR/get-esxi-users.sh`
do
    EXIT=0
    isinlist $USER_NAME "root,dcui,vpxuser,$EXCLUDED_USER_NAMES" || EXIT=$?
    if [ "$EXIT" -ne "1" ]; then
        echo "Applying permissions for $USER_NAME"
        $BASEDIR/add-esxi-vm-permission.sh $VM_NAME $USER_NAME $ROLE_NAME
    else
        echo "Skipping user $USER_NAME"
    fi
done

