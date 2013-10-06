#!/bin/bash
set -e

ESXI_USER=root
ESXI_HOST=10.7.2.2
IPS_FILE_NAME=/tmp/ips.txt

RDO_ADMIN=root
RDO_ADMIN_PASSWORD=Passw0rd

ANSWERS_FILE=packstack_answers.conf

BASEDIR=$(dirname $0)

read CONTROLLER_VM_IP NETWORK_VM_IP QEMU_COMPUTE_VM_IP HYPERV_COMPUTE_VM_IP <<< `ssh $ESXI_USER@$ESXI_HOST "cat $IPS_FILE_NAME" | perl -n -e'/rdotest3_[a-z_]+:(.+\n)/ && print $1'`

SSH_KEY_FILE=`mktemp -u /tmp/rdo.XXXXXX`
SSH_KEY_FILE_PUB=$SSH_KEY_FILE.pub
ssh-keygen -q -t rsa -f $SSH_KEY_FILE -N "" -b 4096

echo "Configuring SSH publick key authetication on the RDO hosts"

configure_ssh_pubkey_auth () {
    HOST=$1
    ssh-keygen -R $HOST
    $BASEDIR/scppass.sh $SSH_KEY_FILE_PUB $RDO_ADMIN@$HOST:$SSH_KEY_FILE_PUB "$RDO_ADMIN_PASSWORD"
    $BASEDIR/sshpass.sh $RDO_ADMIN@$HOST "$RDO_ADMIN_PASSWORD" "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat $SSH_KEY_FILE_PUB >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && restorecon -R -v ~/.ssh"
}

configure_ssh_pubkey_auth $CONTROLLER_VM_IP
configure_ssh_pubkey_auth $NETWORK_VM_IP
configure_ssh_pubkey_auth $QEMU_COMPUTE_VM_IP

#ssh-keygen -R $CONTROLLER_VM_IP
#$BASEDIR/scppass.sh $SSH_KEY_FILE_PUB $RDO_ADMIN@$CONTROLLER_VM_IP:$SSH_KEY_FILE_PUB "$RDO_ADMIN_PASSWORD"
#$BASEDIR/sshpass.sh $RDO_ADMIN@$CONTROLLER_VM_IP "$RDO_ADMIN_PASSWORD" "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat $SSH_KEY_FILE_PUB >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && restorecon -R -v ~/.ssh"

#ssh-keygen -R $NETWORK_VM_IP
#$BASEDIR/scppass.sh $SSH_KEY_FILE_PUB $RDO_ADMIN@$NETWORK_VM_IP:$SSH_KEY_FILE_PUB "$RDO_ADMIN_PASSWORD"
#$BASEDIR/sshpass.sh $RDO_ADMIN@$NETWORK_VM_IP "$RDO_ADMIN_PASSWORD" "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat $SSH_KEY_FILE_PUB >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && restorecon -R -v ~/.ssh"

#ssh-keygen -R $QEMU_COMPUTE_VM_IP
#$BASEDIR/scppass.sh $SSH_KEY_FILE_PUB $RDO_ADMIN@$QEMU_COMPUTE_VM_IP:$SSH_KEY_FILE_PUB "$RDO_ADMIN_PASSWORD"
#$BASEDIR/sshpass.sh $RDO_ADMIN@$QEMU_COMPUTE_VM_IP "$RDO_ADMIN_PASSWORD" "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat $SSH_KEY_FILE_PUB >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && restorecon -R -v ~/.ssh"

echo "Installing RDO RPMs"

ssh -i $SSH_KEY_FILE $RDO_ADMIN@$CONTROLLER_VM_IP -o 'PasswordAuthentication no' "yum install -y http://rdo.fedorapeople.org/openstack/openstack-grizzly/rdo-release-grizzly.rpm & yum install -y openstack-packstack && yum install -y openstack-utils"

echo "Generating Packstack answer file"

ssh -i $SSH_KEY_FILE $RDO_ADMIN@$CONTROLLER_VM_IP -o 'PasswordAuthentication no' "packstack --gen-answer-file=$ANSWERS_FILE"

echo "Configuring Packstack answer file"

ssh -i $SSH_KEY_FILE $RDO_ADMIN@$CONTROLLER_VM_IP -o 'PasswordAuthentication no' "\
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

ssh -i $SSH_KEY_FILE $RDO_ADMIN@$CONTROLLER_VM_IP -o 'PasswordAuthentication no' "packstack --answer-file=$ANSWERS_FILE"

