SSHUSER=$1
IP=$2
PWD=$3
ARGS=$4

/usr/bin/expect <<EOD
spawn ssh -oStrictHostKeyChecking=no $SSHUSER@$IP "$ARGS"
expect "password"
send "$PWD\n" 
expect eof
EOD

