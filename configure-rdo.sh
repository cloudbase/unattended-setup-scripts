#!/bin/bash
set -e

if [ $# -ne 9 ]; then
    echo "Usage: $0 <esxi_user> <esxi_host> <ssh_key_file> <controller_host_name> <controller_host_ip> <network_host_name> <network_host_ip> <qemu_compute_host_name> <qemu_compute_host_ip>"
    exit 1
fi

ESXI_USER=$1
ESXI_HOST=$2

SSH_KEY_FILE=$3

CONTROLLER_VM_NAME=$4
CONTROLLER_VM_IP=$5
NETWORK_VM_NAME=$6
NETWORK_VM_IP=$7
QEMU_COMPUTE_VM_NAME=$8
QEMU_COMPUTE_VM_IP=$9

RDO_ADMIN=root
RDO_ADMIN_PASSWORD=Passw0rd

ANSWERS_FILE=packstack_answers.conf

DOMAIN=localdomain

MAX_WAIT_SECONDS=600

BASEDIR=$(dirname $0)

if [ ! -f "$SSH_KEY_FILE" ]; then
    ssh-keygen -q -t rsa -f $SSH_KEY_FILE -N "" -b 4096
fi
SSH_KEY_FILE_PUB=$SSH_KEY_FILE.pub

wait_for_listening_port () {
    HOST=$1
    PORT=$2
    TIMEOUT=$3
    nc -z -w$TIMEOUT $HOST $PORT
}

configure_ssh_pubkey_auth () {
    HOST=$1
    ssh-keygen -R $HOST

    wait_for_listening_port $HOST 22 $MAX_WAIT_SECONDS
    $BASEDIR/scppass.sh $SSH_KEY_FILE_PUB $RDO_ADMIN@$HOST:$SSH_KEY_FILE_PUB "$RDO_ADMIN_PASSWORD"
    $BASEDIR/sshpass.sh $RDO_ADMIN@$HOST "$RDO_ADMIN_PASSWORD" "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat $SSH_KEY_FILE_PUB >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && restorecon -R -v ~/.ssh"
}

echo "Configuring SSH public key authentication on the RDO hosts"

configure_ssh_pubkey_auth $CONTROLLER_VM_IP
configure_ssh_pubkey_auth $NETWORK_VM_IP
configure_ssh_pubkey_auth $QEMU_COMPUTE_VM_IP

run_ssh_cmd () {
    SSHUSER_HOST=$1
    CMD=$2
    ssh -i $SSH_KEY_FILE $SSHUSER_HOST -o 'PasswordAuthentication no' "$CMD"
}

run_ssh_cmd_with_retry () {
    SSHUSER_HOST=$1
    CMD=$2
    MAX_RETRIES=10

    COUNTER=0
    while [ $COUNTER -lt $MAX_RETRIES ]; do
        EXIT=0
        run_ssh_cmd $SSHUSER_HOST "$CMD" || EXIT=$?
        if [ $EXIT -eq 0 ]; then
            return 0
        fi
        let COUNTER=COUNTER+1
    done
    return $EXIT
}

config_openstack_network_adapter () {
    SSHUSER_HOST=$1
    ADAPTER=$2    

    run_ssh_cmd_with_retry $SSHUSER_HOST "cat << EOF > /etc/sysconfig/network-scripts/ifcfg-$ADAPTER
DEVICE="$ADAPTER"
BOOTPROTO="none"
MTU="1500"
ONBOOT="yes"
EOF"

    run_ssh_cmd_with_retry $SSHUSER_HOST "ifup $ADAPTER"
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

echo "Configuring networking"

set_hostname $RDO_ADMIN@$CONTROLLER_VM_IP $CONTROLLER_VM_NAME.$DOMAIN $CONTROLLER_VM_IP

config_openstack_network_adapter $RDO_ADMIN@$NETWORK_VM_IP eth1
config_openstack_network_adapter $RDO_ADMIN@$NETWORK_VM_IP eth2
set_hostname $RDO_ADMIN@$NETWORK_VM_IP $NETWORK_VM_NAME.$DOMAIN $NETWORK_VM_IP

config_openstack_network_adapter $RDO_ADMIN@$QEMU_COMPUTE_VM_IP eth1
set_hostname $RDO_ADMIN@$QEMU_COMPUTE_VM_IP $QEMU_COMPUTE_VM_NAME.$DOMAIN $QEMU_COMPUTE_VM_IP

echo "Validating network configuration"

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

set_test_network_config () {
    SSHUSER_HOST=$1
    IFADDR=$2
    ACTION=$3

    if check_interface_exists $SSHUSER_HOST br-eth1; then
        IFACE=br-eth1
    else
        IFACE=eth1
    fi

    set_interface_ip $SSHUSER_HOST $IFACE $IFADDR $ACTION
}

ping_ip () {
    SSHUSER_HOST=$1
    IP=$2

    run_ssh_cmd_with_retry $SSHUSER_HOST "ping -c1 $IP"
}

TEST_IP_BASE=10.13.8
NETWORK_VM_TEST_IP=$TEST_IP_BASE.1
QEMU_COMPUTE_VM_TEST_IP=$TEST_IP_BASE.1

set_test_network_config $RDO_ADMIN@$NETWORK_VM_IP $NETWORK_VM_TEST_IP/24 add
set_test_network_config $RDO_ADMIN@$QEMU_COMPUTE_VM_IP $QEMU_COMPUTE_VM_TEST_IP/24 add

ping_ip $RDO_ADMIN@$NETWORK_VM_IP $QEMU_COMPUTE_VM_TEST_IP
ping_ip $RDO_ADMIN@$QEMU_COMPUTE_VM_IP $NETWORK_VM_TEST_IP

set_test_network_config $RDO_ADMIN@$NETWORK_VM_IP $NETWORK_VM_TEST_IP/24 del
set_test_network_config $RDO_ADMIN@$QEMU_COMPUTE_VM_IP $QEMU_COMPUTE_VM_TEST_IP/24 del

# TODO: Check external network

echo "Installing RDO RPMs on controller"

run_ssh_cmd_with_retry $RDO_ADMIN@$CONTROLLER_VM_IP "yum install -y http://rdo.fedorapeople.org/openstack/openstack-grizzly/rdo-release-grizzly.rpm || EXIT=$?"
run_ssh_cmd_with_retry $RDO_ADMIN@$CONTROLLER_VM_IP "yum install -y openstack-packstack && yum install -y openstack-utils"

echo "Generating Packstack answer file"

run_ssh_cmd_with_retry $RDO_ADMIN@$CONTROLLER_VM_IP "packstack --gen-answer-file=$ANSWERS_FILE"

echo "Configuring Packstack answer file"

run_ssh_cmd_with_retry $RDO_ADMIN@$CONTROLLER_VM_IP "\
openstack-config --set $ANSWERS_FILE general CONFIG_SSH_KEY /root/.ssh/id_rsa.pub && \
openstack-config --set $ANSWERS_FILE general CONFIG_NTP_SERVERS 0.pool.ntp.org,1.pool.ntp.org,2.pool.ntp.org,3.pool.ntp.org && \
openstack-config --set $ANSWERS_FILE general CONFIG_CINDER_VOLUMES_SIZE 20G && \
openstack-config --set $ANSWERS_FILE general CONFIG_NOVA_COMPUTE_HOSTS $QEMU_COMPUTE_VM_IP && \
openstack-config --del $ANSWERS_FILE general CONFIG_NOVA_NETWORK_HOST && \
openstack-config --set $ANSWERS_FILE general CONFIG_QUANTUM_L3_HOSTS $NETWORK_VM_IP && \
openstack-config --set $ANSWERS_FILE general CONFIG_QUANTUM_DHCP_HOSTS $NETWORK_VM_IP && \
openstack-config --set $ANSWERS_FILE general CONFIG_QUANTUM_METADATA_HOSTS $NETWORK_VM_IP && \
openstack-config --set $ANSWERS_FILE general CONFIG_QUANTUM_OVS_TENANT_NETWORK_TYPE vlan && \
openstack-config --set $ANSWERS_FILE general CONFIG_QUANTUM_OVS_VLAN_RANGES physnet1:1000:2000 && \
openstack-config --set $ANSWERS_FILE general CONFIG_QUANTUM_OVS_BRIDGE_MAPPINGS physnet1:br-eth1 && \
openstack-config --set $ANSWERS_FILE general CONFIG_QUANTUM_OVS_BRIDGE_IFACES br-eth1:eth1"

echo "Deploying SSH private key on $CONTROLLER_VM_IP"

scp -i $SSH_KEY_FILE -o 'PasswordAuthentication no' $SSH_KEY_FILE $RDO_ADMIN@$CONTROLLER_VM_IP:.ssh/id_rsa
scp -i $SSH_KEY_FILE -o 'PasswordAuthentication no' $SSH_KEY_FILE_PUB $RDO_ADMIN@$CONTROLLER_VM_IP:.ssh/id_rsa.pub

echo "Running Packstack"

run_ssh_cmd_with_retry $RDO_ADMIN@$CONTROLLER_VM_IP "packstack --answer-file=$ANSWERS_FILE"

echo "Enabling Quantum firewall driver on controller"
run_ssh_cmd_with_retry $RDO_ADMIN@$CONTROLLER_VM_IP "sed -i 's/^#\ firewall_driver/firewall_driver/g' /etc/quantum/plugins/openvswitch/ovs_quantum_plugin.ini && service quantum-server restart"

echo "Applying additional OVS configuration on $NETWORK_VM_IP"

run_ssh_cmd_with_retry $RDO_ADMIN@$NETWORK_VM_IP "ovs-vsctl list-ports br-ex | grep eth2 || ovs-vsctl add-port br-ex eth2"

install_3x_kernel () {
    SSHUSER_HOST=$1
    run_ssh_cmd_with_retry $SSHUSER_HOST "yum install -y centos-release-xen && yum update -y --disablerepo=* --enablerepo=Xen4CentOS kernel" 
}

echo "Installing 3.x kernel on network and compute nodes"

install_3x_kernel $RDO_ADMIN@$NETWORK_VM_IP
install_3x_kernel $RDO_ADMIN@$QEMU_COMPUTE_VM_IP

echo "Rebooting nodes to load the new kernel"

run_ssh_cmd_with_retry $RDO_ADMIN@$CONTROLLER_VM_IP reboot
run_ssh_cmd_with_retry $RDO_ADMIN@$NETWORK_VM_IP reboot
run_ssh_cmd_with_retry $RDO_ADMIN@$QEMU_COMPUTE_VM_IP reboot

echo "Validating configuration"

wait_for_listening_port $CONTROLLER_VM_IP 22 $MAX_WAIT_SECONDS

run_ssh_cmd_with_retry $RDO_ADMIN@$CONTROLLER_VM_IP "source ./keystonerc_admin && nova service-list | sed -e '$d' | awk '(NR > 3) {print $10}' | sed -rn '/down/q1'"

run_ssh_cmd_with_retry $RDO_ADMIN@$CONTROLLER_VM_IP "source ./keystonerc_admin && quantum agent-list -f csv | sed -e '1d' | sed -rn 's/\".*\",\".*\",\".*\",\"(.*)\",.*/\1/p' | sed -rn '/xxx/q1'"

echo "RDO installed!!"

