#!/bin/bash
set -e

echoerr() { echo "$@" 1>&2; }

if [ $# -ne 11 ]; then
    echo "Usage: $0 <esxi_user> <esxi_host> <ssh_key_file> <controller_host_name> <controller_host_ip> <network_host_name> <network_host_ip> <qemu_compute_host_name> <qemu_compute_host_ip> <hyperv_compute_host_name> <hyperv_compute_host_ip>"
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
HYPERV_COMPUTE_VM_NAME=${10}
HYPERV_COMPUTE_VM_IP=${11}

RDO_ADMIN=root
RDO_ADMIN_PASSWORD=Passw0rd

ANSWERS_FILE=packstack_answers.conf
NOVA_CONF_FILE=/etc/nova/nova.conf

DOMAIN=localdomain

MAX_WAIT_SECONDS=600

BASEDIR=$(dirname $0)

echo "Checking prerequisites"

NOTFOUND=0
pip freeze | grep pywinrm > /dev/null || NOTFOUND=1

if [ "$NOTFOUND" -eq 1 ]; then
    echoerr "pywinrm not found. Install with: sudo pip install --pre pywinrm"
    exit 1
fi

if [ ! -f "$SSH_KEY_FILE" ]; then
    ssh-keygen -q -t rsa -f $SSH_KEY_FILE -N "" -b 4096
fi
SSH_KEY_FILE_PUB=$SSH_KEY_FILE.pub

wait_for_listening_port () {
    HOST=$1
    PORT=$2
    TIMEOUT=$3
    nc -z -w$TIMEOUT $HOST $PORT
    echo $?
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

echo "Sync hosts date and time"
update_host_date $RDO_ADMIN@$CONTROLLER_VM_IP
update_host_date $RDO_ADMIN@$NETWORK_VM_IP
update_host_date $RDO_ADMIN@$QEMU_COMPUTE_VM_IP

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

run_ssh_cmd_with_retry $RDO_ADMIN@$CONTROLLER_VM_IP "yum install -y http://rdo.fedorapeople.org/openstack/openstack-grizzly/rdo-release-grizzly.rpm || true"
run_ssh_cmd_with_retry $RDO_ADMIN@$CONTROLLER_VM_IP "yum install -y openstack-packstack"

run_ssh_cmd_with_retry $RDO_ADMIN@$CONTROLLER_VM_IP "yum -y install http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm || true"
run_ssh_cmd_with_retry $RDO_ADMIN@$CONTROLLER_VM_IP "yum install -y crudini"

echo "Generating Packstack answer file"

run_ssh_cmd_with_retry $RDO_ADMIN@$CONTROLLER_VM_IP "packstack --gen-answer-file=$ANSWERS_FILE"

echo "Configuring Packstack answer file"

run_ssh_cmd_with_retry $RDO_ADMIN@$CONTROLLER_VM_IP "\
crudini --set $ANSWERS_FILE general CONFIG_SSH_KEY /root/.ssh/id_rsa.pub && \
crudini --set $ANSWERS_FILE general CONFIG_NTP_SERVERS 0.pool.ntp.org,1.pool.ntp.org,2.pool.ntp.org,3.pool.ntp.org && \
crudini --set $ANSWERS_FILE general CONFIG_CINDER_VOLUMES_SIZE 20G && \
crudini --set $ANSWERS_FILE general CONFIG_NOVA_COMPUTE_HOSTS $QEMU_COMPUTE_VM_IP && \
crudini --del $ANSWERS_FILE general CONFIG_NOVA_NETWORK_HOST && \
crudini --set $ANSWERS_FILE general CONFIG_QUANTUM_L3_HOSTS $NETWORK_VM_IP && \
crudini --set $ANSWERS_FILE general CONFIG_QUANTUM_DHCP_HOSTS $NETWORK_VM_IP && \
crudini --set $ANSWERS_FILE general CONFIG_QUANTUM_METADATA_HOSTS $NETWORK_VM_IP && \
crudini --set $ANSWERS_FILE general CONFIG_QUANTUM_OVS_TENANT_NETWORK_TYPE vlan && \
crudini --set $ANSWERS_FILE general CONFIG_QUANTUM_OVS_VLAN_RANGES physnet1:1000:2000 && \
crudini --set $ANSWERS_FILE general CONFIG_QUANTUM_OVS_BRIDGE_MAPPINGS physnet1:br-eth1 && \
crudini --set $ANSWERS_FILE general CONFIG_QUANTUM_OVS_BRIDGE_IFACES br-eth1:eth1"

echo "Deploying SSH private key on $CONTROLLER_VM_IP"

scp -i $SSH_KEY_FILE -o 'PasswordAuthentication no' $SSH_KEY_FILE $RDO_ADMIN@$CONTROLLER_VM_IP:.ssh/id_rsa
scp -i $SSH_KEY_FILE -o 'PasswordAuthentication no' $SSH_KEY_FILE_PUB $RDO_ADMIN@$CONTROLLER_VM_IP:.ssh/id_rsa.pub

echo "Running Packstack"

run_ssh_cmd_with_retry $RDO_ADMIN@$CONTROLLER_VM_IP "packstack --answer-file=$ANSWERS_FILE"

echo "Disabling Nova API rate limits"
run_ssh_cmd_with_retry $RDO_ADMIN@$CONTROLLER_VM_IP "crudini --set $NOVA_CONF_FILE DEFAULT api_rate_limit False"

echo "Enabling Quantum firewall driver on controller"
run_ssh_cmd_with_retry $RDO_ADMIN@$CONTROLLER_VM_IP "sed -i 's/^#\ firewall_driver/firewall_driver/g' /etc/quantum/plugins/openvswitch/ovs_quantum_plugin.ini && service quantum-server restart"

echo "Set libvirt_type on QEMU/KVM compute node"
run_ssh_cmd_with_retry $RDO_ADMIN@$QEMU_COMPUTE_VM_IP "grep vmx /proc/cpuinfo > /dev/null && crudini --set $NOVA_CONF_FILE DEFAULT libvirt_type kvm || true"

echo "Applying additional OVS configuration on $NETWORK_VM_IP"

run_ssh_cmd_with_retry $RDO_ADMIN@$NETWORK_VM_IP "ovs-vsctl list-ports br-ex | grep eth2 || ovs-vsctl add-port br-ex eth2"

install_3x_kernel () {
    SSHUSER_HOST=$1
    run_ssh_cmd_with_retry $SSHUSER_HOST "yum install -y centos-release-xen && yum update -y --disablerepo=* --enablerepo=Xen4CentOS kernel" 
}

#echo "Installing 3.x kernel on network and compute nodes"

#install_3x_kernel $RDO_ADMIN@$NETWORK_VM_IP
#install_3x_kernel $RDO_ADMIN@$QEMU_COMPUTE_VM_IP

echo "Rebooting Linux nodes to load the new kernel"

run_ssh_cmd_with_retry $RDO_ADMIN@$CONTROLLER_VM_IP reboot
run_ssh_cmd_with_retry $RDO_ADMIN@$NETWORK_VM_IP reboot
run_ssh_cmd_with_retry $RDO_ADMIN@$QEMU_COMPUTE_VM_IP reboot

echo "Waiting for WinRM HTTPS port to be available on $HYPERV_COMPUTE_VM_IP"
wait_for_listening_port $HYPERV_COMPUTE_VM_IP 5986 $MAX_WAIT_SECONDS

echo "Configuring external virtual switch on Hyper-V"

HYPERV_ADMIN=Administrator
HYPERV_PASSWORD=$RDO_ADMIN_PASSWORD
HYPERV_VSWITCH=external

$BASEDIR/create-hyperv-external-vswitch.sh $HYPERV_COMPUTE_VM_IP $HYPERV_ADMIN $HYPERV_PASSWORD $HYPERV_VSWITCH

echo "Deploy Hyper-V OpenStack components on $HYPERV_COMPUTE_VM_IP"

MSI_FILE=HyperVNovaCompute_Grizzly.msi

$BASEDIR/wsmancmd.py -U https://$HYPERV_COMPUTE_VM_IP:5986/wsman -u $HYPERV_ADMIN -p $HYPERV_PASSWORD powershell Invoke-WebRequest -Uri http://www.cloudbase.it/downloads/$MSI_FILE -OutFile \$ENV:TEMP\\$MSI_FILE

get_openstack_option_value () {

    SSHUSER_HOST=$1
    SECTION_NAME=$2
    OPTION_NAME=$3
    CONFIG_FILE_PATH=$4

    run_ssh_cmd_with_retry $SSHUSER_HOST "crudini --get $CONFIG_FILE_PATH $SECTION_NAME $OPTION_NAME"
}


GLANCE_HOST=`get_openstack_option_value $RDO_ADMIN@$CONTROLLER_VM_IP general CONFIG_GLANCE_HOST $ANSWERS_FILE`
QPID_HOST=`get_openstack_option_value $RDO_ADMIN@$CONTROLLER_VM_IP general CONFIG_QPID_HOST $ANSWERS_FILE`
QUANTUM_KS_PW=`get_openstack_option_value $RDO_ADMIN@$CONTROLLER_VM_IP general CONFIG_QUANTUM_KS_PW $ANSWERS_FILE`

QPID_USERNAME=`get_openstack_option_value $RDO_ADMIN@$CONTROLLER_VM_IP DEFAULT qpid_username $NOVA_CONF_FILE`
QPID_PASSWORD=`get_openstack_option_value $RDO_ADMIN@$CONTROLLER_VM_IP DEFAULT qpid_password $NOVA_CONF_FILE`

QUANTUM_URL=`get_openstack_option_value $RDO_ADMIN@$CONTROLLER_VM_IP DEFAULT quantum_url $NOVA_CONF_FILE`
QUANTUM_ADMIN_AUTH_URL=`get_openstack_option_value $RDO_ADMIN@$CONTROLLER_VM_IP DEFAULT quantum_admin_auth_url $NOVA_CONF_FILE`
QUANTUM_ADMIN_TENANT_NAME=`get_openstack_option_value $RDO_ADMIN@$CONTROLLER_VM_IP DEFAULT quantum_admin_tenant_name $NOVA_CONF_FILE`

QUANTUM_ADMIN_USERNAME=quantum
GLANCE_PORT=9292
QPID_PORT=5672

$BASEDIR/wsmancmd.py -U https://$HYPERV_COMPUTE_VM_IP:5986/wsman -u $HYPERV_ADMIN -p $HYPERV_PASSWORD msiexec /i %TEMP%\\$MSI_FILE /qn /l*v %TEMP%\\HyperVNovaCompute_setup_log.txt \
ADDLOCAL=HyperVNovaCompute,QuantumHyperVAgent,iSCSISWInitiator,FreeRDP GLANCEHOST=$GLANCE_HOST GLANCEPORT=$GLANCE_PORT RPCBACKEND=ApacheQpid RPCBACKENDHOST=$QPID_HOST RPCBACKENDPORT=$QPID_PORT \
RPCBACKENDUSER=$QPID_USERNAME RPCBACKENDPASSWORD=$QPID_PASSWORD INSTANCESPATH=C:\\OpenStack\\Instances ADDVSWITCH=0 VSWITCHNAME=$HYPERV_VSWITCH USECOWIMAGES=1 LOGDIR=C:\\OpenStack\\Log ENABLELOGGING=1 \
VERBOSELOGGING=1 QUANTUMURL=$QUANTUM_URL QUANTUMADMINTENANTNAME=$QUANTUM_ADMIN_TENANT_NAME QUANTUMADMINUSERNAME=$QUANTUM_ADMIN_USERNAME QUANTUMADMINPASSWORD=$QUANTUM_KS_PW QUANTUMADMINAUTHURL=$QUANTUM_ADMIN_AUTH_URL

echo "Renaming Hyper-V host $HYPERV_COMPUTE_VM_IP"

$BASEDIR/wsmancmd.py -U https://$HYPERV_COMPUTE_VM_IP:5986/wsman -u $HYPERV_ADMIN -p $HYPERV_PASSWORD powershell Rename-Computer $HYPERV_COMPUTE_VM_NAME

echo "Rebooting Hyper-V host $HYPERV_COMPUTE_VM_IP"

$BASEDIR/wsmancmd.py -U https://$HYPERV_COMPUTE_VM_IP:5986/wsman -u $HYPERV_ADMIN -p $HYPERV_PASSWORD "shutdown /r /t 0"

echo "Wait for reboot"
sleep 120

echo "Waiting for SSH to be available on $CONTROLLER_VM_IP"
wait_for_listening_port $CONTROLLER_VM_IP 22 $MAX_WAIT_SECONDS

#echo "Restarting Nova services on controller"
#run_ssh_cmd_with_retry $RDO_ADMIN@$CONTROLLER_VM_IP "for SVC in \`chkconfig --list | grep openstack-nova | grep ":on" | awk '{ print \$1 }'\`; do service \$SVC restart; done"

#echo "Restarting Nova services on QEMU/KVM compute node"
#run_ssh_cmd_with_retry $RDO_ADMIN@$QEMU_COMPUTE_VM_IP "for SVC in \`chkconfig --list | grep openstack-nova | grep ":on" | awk '{ print \$1 }'\`; do service \$SVC restart; done"

#sleep 5

echo "Validating Nova configuration"
run_ssh_cmd_with_retry $RDO_ADMIN@$CONTROLLER_VM_IP "source ./keystonerc_admin && nova service-list | sed -e '$d' | awk '(NR > 3) {print $10}' | sed -rn '/down/q1'" 10

echo "Validating Quantum configuration"
run_ssh_cmd_with_retry $RDO_ADMIN@$CONTROLLER_VM_IP "source ./keystonerc_admin && quantum agent-list -f csv | sed -e '1d' | sed -rn 's/\".*\",\".*\",\".*\",\"(.*)\",.*/\1/p' | sed -rn '/xxx/q1'" 10

echo "RDO installed!"
echo "Controller IP: $CONTROLLER_VM_IP"
echo "SSH key file: $SSH_KEY_FILE"

