echoerr() { echo "$@" 1>&2; }

exec_with_retry2 () {
    MAX_RETRIES=$1
    INTERVAL=$2

    COUNTER=0
    while [ $COUNTER -lt $MAX_RETRIES ]; do
        EXIT=0
        eval '${@:3}' || EXIT=$?
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

exec_with_retry () {
    CMD=$1
    MAX_RETRIES=${2-10}
    INTERVAL=${3-0}

    exec_with_retry2 $MAX_RETRIES $INTERVAL $CMD
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
    ssh -t -i $SSH_KEY_FILE $SSHUSER_HOST -o 'PasswordAuthentication no' "$CMD"
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
    run_ssh_cmd_with_retry $SSHUSER_HOST "sudo ntpdate pool.ntp.org"
}

# TODO: rename to set_hostname_centos
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

set_hostname_ubuntu () {
    SSHUSER_HOST=$1
    FQDN=$2
    HOSTNAME=${FQDN%%.*}

    run_ssh_cmd_with_retry $SSHUSER_HOST "sudo sed -i 's/^127.0.1.1\s*.\+$/127.0.1.1\t'"$FQDN"' '"$HOSTNAME"'/g' /etc/hosts"
    run_ssh_cmd_with_retry $SSHUSER_HOST "sudo hostname $FQDN"
    run_ssh_cmd_with_retry $SSHUSER_HOST "sudo sh -c \"echo $FQDN > /etc/hostname\""
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

    # Return an empty result if the value is not found
    # TODO: improve the hack that removes the trailing '\r\n'
    run_ssh_cmd_with_retry $SSHUSER_HOST "crudini --get $CONFIG_FILE_PATH $SECTION_NAME $OPTION_NAME 2> /dev/null || if [ \"\$?\" == \"1\" ]; then true; else false; fi" | tr -d '\r'
}

configure_ssh_pubkey_auth () {
    USERNAME=$1
    HOST=$2
    SSH_KEY_FILE_PUB=$3
    PASSWORD=$4

    MAX_WAIT_SECONDS=300

    PUBKEYFILE=`mktemp -u /tmp/ssh_key_pub.XXXXXX`

    ssh-keygen -R $HOST

    wait_for_listening_port $HOST 22 $MAX_WAIT_SECONDS
    exec_with_retry2 10 0 $BASEDIR/scppass.sh $SSH_KEY_FILE_PUB $USERNAME@$HOST:$PUBKEYFILE "$PASSWORD"
    exec_with_retry2 10 0 $BASEDIR/sshpass.sh $USERNAME@$HOST "$PASSWORD" "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat $PUBKEYFILE >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && (\[ ! -x /sbin/restorecon \] || restorecon -R -v ~/.ssh)"
}

disable_sudo_password_prompt () {
    SSHUSER_HOST=$1
    SSH_KEY_FILE=$2
    PWD=$3

    exec_with_retry2 10 0 /usr/bin/expect <<EOD
spawn ssh -oStrictHostKeyChecking=no -oCheckHostIP=no -i $SSH_KEY_FILE -t $SSHUSER_HOST "sudo sh -c 'echo \"%sudo ALL=(ALL) NOPASSWD: ALL\" >> /etc/sudoers'"
expect "password"
send "$PWD\n"
expect eof
EOD
}

config_openstack_network_adapter_ubuntu () {
    SSHUSER_HOST=$1
    ADAPTER=$2

    run_ssh_cmd_with_retry $SSHUSER_HOST "grep \"iface $ADAPTER\" /etc/network/interfaces ||  sudo sh -c \"cat << EOF >> /etc/network/interfaces

auto $ADAPTER
iface $ADAPTER inet manual
up ip link set $ADAPTER up
down ip link set $ADAPTER down
EOF\""

    run_ssh_cmd_with_retry $SSHUSER_HOST "sudo ifup $ADAPTER"
}

add_openstack_vars_to_bashrc () {
    SSHUSER_HOST=$1
    CONTROLLER_VM_IP=$2
    run_ssh_cmd_with_retry $SSHUSER_HOST "cat << EOF >> ~/.bashrc

export OS_USERNAME=admin
export OS_TENANT_NAME=admin
export OS_PASSWORD=Passw0rd
export OS_AUTH_URL=http://$CONTROLLER_VM_IP:35357/v2.0/
EOF"
}

