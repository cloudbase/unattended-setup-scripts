#!/bin/bash
set -e

if [ $# -lt 2 ]; then
    echo "Usage: $0 <ssh_user>@<ssh_host> <ssh_password> [<ssh_command>]"
    exit 1
fi

SSHUSER_HOST=$1
PWD=$2
ARGS="${@:3}"

/usr/bin/expect <<EOD
spawn ssh -oStrictHostKeyChecking=no -oCheckHostIP=no $SSHUSER_HOST $ARGS
expect "password"
send "$PWD\n" 
expect eof
EOD

