echoerr() { echo "$@" 1>&2; }

exec_with_retry () {
    CMD=$1
    MAX_RETRIES=${2-10}
    INTERVAL=$3

    COUNTER=0
    while [ $COUNTER -lt $MAX_RETRIES ]; do
        EXIT=0
        eval '$CMD' || EXIT=$?
        if [ $EXIT -eq 0 ]; then
            return 0
        fi
        let COUNTER=COUNTER+1

        if [ -n "$INTERVAL" ]; then
            sleep $INTERVAL
        fi
    done
    return $EXIT
}

run_wsmancmd_with_retry () {
    HOST=$1
    USERNAME=$2
    PASSWORD=$3
    CMD=$4

    exec_with_retry "$BASEDIR/wsmancmd.py -U https://$HOST:5986/wsman -u $USERNAME -p $PASSWORD $CMD"
}

wait_for_listening_port () {
    HOST=$1
    PORT=$2
    TIMEOUT=$3
    exec_with_retry "nc -z -w$TIMEOUT $HOST $PORT" 10 5
}

run_ssh_cmd () {
    SSHUSER_HOST=$1
    CMD=$2
    ssh -i $SSH_KEY_FILE $SSHUSER_HOST -o 'PasswordAuthentication no' "$CMD"
}

run_ssh_cmd_with_retry () {
    SSHUSER_HOST=$1
    CMD=$2
    INTERVAL=$3
    MAX_RETRIES=10

    COUNTER=0
    while [ $COUNTER -lt $MAX_RETRIES ]; do
        EXIT=0
        run_ssh_cmd $SSHUSER_HOST "$CMD" || EXIT=$?
        if [ $EXIT -eq 0 ]; then
            return 0
        fi
        let COUNTER=COUNTER+1

        if [ -n "$INTERVAL" ]; then
            sleep $INTERVAL
        fi
    done
    return $EXIT
}

update_host_date () {
    SSHUSER_HOST=$1
    run_ssh_cmd_with_retry $SSHUSER_HOST "ntpdate pool.ntp.org"
}

set_hostname () {
    SSHUSER_HOST=$1
    FQDN=$2
    IP=$3
    HOSTNAME=${FQDN%%.*}

    run_ssh_cmd_with_retry $SSHUSER_HOST "sed -i 's/^HOSTNAME=.\+$/HOSTNAME=$FQDN/g' /etc/sysconfig/network"
    run_ssh_cmd_with_retry $SSHUSER_HOST "sed -r '/$FQDN/d' -i /etc/hosts && echo '$IP $HOSTNAME $FQDN' >> /etc/hosts"
    run_ssh_cmd_with_retry $SSHUSER_HOST "hostname $FQDN"
    run_ssh_cmd_with_retry $SSHUSER_HOST "service network restart"
}

check_interface_exists () {
    SSHUSER_HOST=$1
    IFACE=$2

    IFACE_EXISTS=0
    run_ssh_cmd_with_retry $SSHUSER_HOST "ifconfig $IFACE 2> /dev/null" || IFACE_EXISTS=1
    return $IFACE_EXISTS
}

set_interface_ip () {
    SSHUSER_HOST=$1
    IFACE=$2
    IFADDR=$3
    ACTION=$4

    run_ssh_cmd_with_retry $SSHUSER_HOST "ip addr $ACTION $IFADDR dev $IFACE"
}

ping_ip () {
    SSHUSER_HOST=$1
    IP=$2

    run_ssh_cmd_with_retry $SSHUSER_HOST "ping -c1 $IP"
}

get_openstack_option_value () {

    SSHUSER_HOST=$1
    SECTION_NAME=$2
    OPTION_NAME=$3
    CONFIG_FILE_PATH=$4

    run_ssh_cmd_with_retry $SSHUSER_HOST "crudini --get $CONFIG_FILE_PATH $SECTION_NAME $OPTION_NAME"
}


