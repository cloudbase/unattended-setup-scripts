#!/bin/bash
set -e

if [ $# -ne 13 ]; then
    echo "Usage: $0 <hyperv_host_ip> <hyperv_admin_username> <hyperv_password> <openstack_release> <vswitch_name> <glance_host> <qpid_host> <qpid_username> <qpid_password> <quantum_url> <quantum_admin_auth_url> <quantum_admin_tenant_name> <quantum_admin_password>"
    exit 1
fi

HYPERV_COMPUTE_VM_IP=$1
HYPERV_ADMIN=$2
HYPERV_PASSWORD=$3
OPENSTACK_RELEASE=$4
HYPERV_VSWITCH=$5
GLANCE_HOST=$6
QPID_HOST=$7
QPID_USERNAME=$8
QPID_PASSWORD=$9
QUANTUM_URL=${10}
QUANTUM_ADMIN_AUTH_URL=${11}
QUANTUM_ADMIN_TENANT_NAME=${12}
QUANTUM_KS_PW=${13}

QUANTUM_ADMIN_USERNAME=quantum
GLANCE_PORT=9292
QPID_PORT=5672

BASEDIR=$(dirname $0)

. $BASEDIR/utils.sh

if [ "$OPENSTACK_RELEASE" == "grizzly" ]; then
    MSI_FILE=HyperVNovaCompute_Grizzly.msi
elif [ "$OPENSTACK_RELEASE" == "master" ]; then
    MSI_FILE=HyperVNovaCompute_Beta.msi
else
    echoerr "Unsupported OpenStack release: $OPENSTACK_RELEASE"
    exit 1
fi

echo "OpenStack release: $OPENSTACK_RELEASE"

echo "Configuring external virtual switch on Hyper-V"

exec_with_retry "$BASEDIR/create-hyperv-external-vswitch.sh $HYPERV_COMPUTE_VM_IP $HYPERV_ADMIN $HYPERV_PASSWORD $HYPERV_VSWITCH"

echo "Deploy Hyper-V OpenStack components on $HYPERV_COMPUTE_VM_IP"

run_wsmancmd_with_retry $HYPERV_COMPUTE_VM_IP $HYPERV_ADMIN $HYPERV_PASSWORD "powershell -NonInteractive Invoke-WebRequest -Uri http://www.cloudbase.it/downloads/$MSI_FILE -OutFile \$ENV:TEMP\\$MSI_FILE"

run_wsmancmd_with_retry $HYPERV_COMPUTE_VM_IP $HYPERV_ADMIN $HYPERV_PASSWORD "msiexec /i %TEMP%\\$MSI_FILE /qn /l*v %TEMP%\\HyperVNovaCompute_setup_log.txt \
ADDLOCAL=HyperVNovaCompute,QuantumHyperVAgent,iSCSISWInitiator,FreeRDP GLANCEHOST=$GLANCE_HOST GLANCEPORT=$GLANCE_PORT RPCBACKEND=ApacheQpid RPCBACKENDHOST=$QPID_HOST RPCBACKENDPORT=$QPID_PORT \
RPCBACKENDUSER=$QPID_USERNAME RPCBACKENDPASSWORD=$QPID_PASSWORD INSTANCESPATH=C:\\OpenStack\\Instances ADDVSWITCH=0 VSWITCHNAME=$HYPERV_VSWITCH USECOWIMAGES=1 LOGDIR=C:\\OpenStack\\Log ENABLELOGGING=1 \
VERBOSELOGGING=1 QUANTUMURL=$QUANTUM_URL QUANTUMADMINTENANTNAME=$QUANTUM_ADMIN_TENANT_NAME QUANTUMADMINUSERNAME=$QUANTUM_ADMIN_USERNAME QUANTUMADMINPASSWORD=$QUANTUM_KS_PW QUANTUMADMINAUTHURL=$QUANTUM_ADMIN_AUTH_URL"

