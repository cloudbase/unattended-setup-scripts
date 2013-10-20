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

echo "Setting host name"
set_hostname_ubuntu $ADMIN_USER@$CONTROLLER_VM_IP $CONTROLLER_VM_NAME
# TODO: set Windows host name

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

echo "DevStack configured!"
echo "Controller IP: $CONTROLLER_VM_IP"
echo "SSH key file: $SSH_KEY_FILE"

