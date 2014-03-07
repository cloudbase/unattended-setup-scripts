#!/bin/bash
set -e

if [ $# -ne 5 ]; then
    echo "Usage: $0 <ssh_key_file> <controller_host_name> <controller_host_ip> <hyperv_compute_host_name> <hyperv_compute_host_ip>"
    exit 1
fi

SSH_KEY_FILE=$1

CONTROLLER_VM_NAME=$2
CONTROLLER_VM_IP=$3
HYPERV_COMPUTE_VM_NAME=$4
HYPERV_COMPUTE_VM_IP=$5

ADMIN_USER=ubuntu
ADMIN_PASSWORD=Passw0rd

HYPERV_ADMIN=Administrator
HYPERV_PASSWORD=$ADMIN_PASSWORD

NOVA_CONF_FILE=/etc/nova/nova.conf
CEILOMETER_CONF_FILE=/etc/ceilometer/ceilometer.conf

MAX_WAIT_SECONDS=600

BASEDIR=$(dirname $0)

. $BASEDIR/utils.sh

if [ ! -f "$SSH_KEY_FILE" ]; then
    ssh-keygen -q -t rsa -f $SSH_KEY_FILE -N "" -b 4096
fi
SSH_KEY_FILE_PUB=$SSH_KEY_FILE.pub

echo "Configuring SSH public key authentication"
configure_ssh_pubkey_auth $ADMIN_USER $CONTROLLER_VM_IP $SSH_KEY_FILE_PUB $ADMIN_PASSWORD

echo "Disabling sudo password prompt"
disable_sudo_password_prompt $ADMIN_USER@$CONTROLLER_VM_IP $SSH_KEY_FILE $ADMIN_PASSWORD

echo "Setting controller host name"
set_hostname_ubuntu $ADMIN_USER@$CONTROLLER_VM_IP $CONTROLLER_VM_NAME

echo "Renaming and rebooting Hyper-V host $HYPERV_COMPUTE_VM_IP"
exec_with_retry "$BASEDIR/rename-windows-host.sh $HYPERV_COMPUTE_VM_IP $HYPERV_ADMIN $HYPERV_PASSWORD $HYPERV_COMPUTE_VM_NAME" 30 30

echo "Configure networking"
config_openstack_network_adapter_ubuntu $ADMIN_USER@$CONTROLLER_VM_IP eth1
config_openstack_network_adapter_ubuntu $ADMIN_USER@$CONTROLLER_VM_IP eth2

echo "Sync hosts date and time"
update_host_date $ADMIN_USER@$CONTROLLER_VM_IP
# TODO: Sync Windows date and time

echo "Installing git"
run_ssh_cmd_with_retry $ADMIN_USER@$CONTROLLER_VM_IP "sudo apt-get install -y git"

echo "Unstack if DevStack is already running"
run_ssh_cmd_with_retry $ADMIN_USER@$CONTROLLER_VM_IP "[ ! -d devstack ] || (cd devstack && ./unstack.sh)"

echo "Downloading DevStack"
run_ssh_cmd_with_retry $ADMIN_USER@$CONTROLLER_VM_IP "sudo rm -rf devstack"
run_ssh_cmd_with_retry $ADMIN_USER@$CONTROLLER_VM_IP "git clone https://github.com/openstack-dev/devstack.git"

echo "Downloading DevStack localrc"
run_ssh_cmd_with_retry $ADMIN_USER@$CONTROLLER_VM_IP "wget https://raw.github.com/cloudbase/devstack-localrc/master/all-in-one-localrc -O devstack/localrc"
run_ssh_cmd_with_retry $SSHUSER_HOST "sudo sed -i 's/^HOST_IP\s*=.\+$/HOST_IP='"$CONTROLLER_VM_IP"'/g' devstack/localrc"

echo "Running DevStack"
run_ssh_cmd_with_retry $ADMIN_USER@$CONTROLLER_VM_IP "cd devstack && ./unstack.sh && ./stack.sh"

echo "Configuring OpenVSwitch"
run_ssh_cmd_with_retry $ADMIN_USER@$CONTROLLER_VM_IP "sudo ovs-vsctl show | grep 'Bridge \"br-eth1\"' > /dev/null || sudo ovs-vsctl add-br br-eth1"
run_ssh_cmd_with_retry $ADMIN_USER@$CONTROLLER_VM_IP "sudo ovs-vsctl show | grep 'Port \"eth1\"' > /dev/null || sudo ovs-vsctl add-port br-eth1 eth1"
run_ssh_cmd_with_retry $ADMIN_USER@$CONTROLLER_VM_IP "sudo ovs-vsctl show | grep 'Port \"eth2\"' > /dev/null || sudo ovs-vsctl add-port br-ex eth2"

echo "Adding OpenStack vars to .bashrc"
add_openstack_vars_to_bashrc $ADMIN_USER@$CONTROLLER_VM_IP $CONTROLLER_VM_IP

echo "Install crudini on controller"

run_ssh_cmd_with_retry $ADMIN_USER@$CONTROLLER_VM_IP "git clone https://github.com/pixelb/crudini.git"
run_ssh_cmd_with_retry $ADMIN_USER@$CONTROLLER_VM_IP "sudo apt-get install -y python-iniparse"
run_ssh_cmd_with_retry $ADMIN_USER@$CONTROLLER_VM_IP "sudo cp crudini/crudini /usr/local/bin"

echo "Getting Nova config options for Hyper-V"

RPC_BACKEND_HOST=`get_openstack_option_value $ADMIN_USER@$CONTROLLER_VM_IP DEFAULT rabbit_host $NOVA_CONF_FILE`

if [ "$RPC_BACKEND_HOST" == "localhost" ]; then
    RPC_BACKEND_HOST=$CONTROLLER_VM_IP
fi

RPC_BACKEND_PASSWORD=`get_openstack_option_value $ADMIN_USER@$CONTROLLER_VM_IP DEFAULT rabbit_password $NOVA_CONF_FILE`

NEUTRON_URL=`get_openstack_option_value $ADMIN_USER@$CONTROLLER_VM_IP DEFAULT neutron_url $NOVA_CONF_FILE`
NEUTRON_ADMIN_AUTH_URL=`get_openstack_option_value $ADMIN_USER@$CONTROLLER_VM_IP DEFAULT neutron_admin_auth_url $NOVA_CONF_FILE`
NEUTRON_ADMIN_TENANT_NAME=`get_openstack_option_value $ADMIN_USER@$CONTROLLER_VM_IP DEFAULT neutron_admin_tenant_name $NOVA_CONF_FILE`
NEUTRON_ADMIN_USERNAME=`get_openstack_option_value $ADMIN_USER@$CONTROLLER_VM_IP DEFAULT neutron_admin_username $NOVA_CONF_FILE`
NEUTRON_ADMIN_PASSWORD=`get_openstack_option_value $ADMIN_USER@$CONTROLLER_VM_IP DEFAULT neutron_admin_password $NOVA_CONF_FILE`

CEILOMETER=`run_ssh_cmd_with_retry $ADMIN_USER@$CONTROLLER_VM_IP "if [ -f \"$CEILOMETER_CONF_FILE\" ]; then echo 1; fi"`

if [ -n "$CEILOMETER" ]; then
    echo "Getting Ceilometer config options for Hyper-V"

    CEILOMETER_ADMIN_AUTH_URL=`get_openstack_option_value $ADMIN_USER@$CONTROLLER_VM_IP DEFAULT os_auth_url $CEILOMETER_CONF_FILE`
    CEILOMETER_ADMIN_TENANT_NAME=`get_openstack_option_value $ADMIN_USER@$CONTROLLER_VM_IP DEFAULT os_tenant_name $CEILOMETER_CONF_FILE`
    CEILOMETER_ADMIN_USERNAME=`get_openstack_option_value $ADMIN_USER@$CONTROLLER_VM_IP DEFAULT os_username $CEILOMETER_CONF_FILE`
    CEILOMETER_ADMIN_PASSWORD=`get_openstack_option_value $ADMIN_USER@$CONTROLLER_VM_IP DEFAULT os_password $CEILOMETER_CONF_FILE`
    CEILOMETER_METERING_SECRET=`get_openstack_option_value $ADMIN_USER@$CONTROLLER_VM_IP DEFAULT metering_secret $CEILOMETER_CONF_FILE`

    if [ -z "$CEILOMETER_ADMIN_AUTH_URL" ]; then
        CEILOMETER_ADMIN_AUTH_URL=$NEUTRON_ADMIN_AUTH_URL
    fi
fi

# TODO: read Glance host/port from nova.conf
GLANCE_HOST=$CONTROLLER_VM_IP
GLANCE_PORT=9292
RPC_BACKEND_USERNAME=guest
RPC_BACKEND_PORT=5672
HYPERV_VSWITCH_NAME=external
RPC_BACKEND=RabbitMQ
OPENSTACK_RELEASE=master

echo "Waiting for WinRM HTTPS port to be available on $HYPERV_COMPUTE_VM_IP"
wait_for_listening_port $HYPERV_COMPUTE_VM_IP 5986 $MAX_WAIT_SECONDS

$BASEDIR/deploy-hyperv-compute.sh "$HYPERV_COMPUTE_VM_IP" "$HYPERV_ADMIN" "$HYPERV_PASSWORD" \
"$OPENSTACK_RELEASE" "$HYPERV_VSWITCH_NAME" "$GLANCE_HOST" "$RPC_BACKEND" "$RPC_BACKEND_HOST" \
"$RPC_BACKEND_USERNAME" "$RPC_BACKEND_PASSWORD" "$NEUTRON_URL" "$NEUTRON_ADMIN_AUTH_URL" \
"$NEUTRON_ADMIN_TENANT_NAME" "$NEUTRON_ADMIN_USERNAME" "$NEUTRON_ADMIN_PASSWORD" \
"$CEILOMETER_ADMIN_AUTH_URL" "$CEILOMETER_ADMIN_TENANT_NAME" "$CEILOMETER_ADMIN_USERNAME" \
"$CEILOMETER_ADMIN_PASSWORD" "$CEILOMETER_METERING_SECRET"

echo "DevStack configured!"
echo "SSH access:"
echo "ssh -i $SSH_KEY_FILE $ADMIN_USER@$CONTROLLER_VM_IP"
