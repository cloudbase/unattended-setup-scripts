#!/bin/sh
set -e

if [ $# -ne 3 ]; then
    echo "Usage: $0 <src> <dest> <ssh_password>"
    exit 1
fi

SRC=$1
DEST=$2
PWD=$3

/usr/bin/expect <<EOD
spawn scp -oStrictHostKeyChecking=no -oCheckHostIP=no "$SRC" "$DEST"
expect "password"
send "$PWD\n" 
expect eof
EOD

