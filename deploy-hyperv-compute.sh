#!/bin/bash
set -e

if [ $# -ne 14 ]; then
    echo "Usage: $0 <hyperv_host_ip> <hyperv_admin_username> <hyperv_password> <openstack_release> <vswitch_name> <glance_host> <rpc_backend> <rpc_backend_host> <rpc_backend_username> <rpc_backend_password> <quantum_url> <quantum_admin_auth_url> <quantum_admin_tenant_name> <quantum_admin_password>"
    exit 1
fi

HYPERV_COMPUTE_VM_IP=$1
HYPERV_ADMIN=$2
HYPERV_PASSWORD=$3
OPENSTACK_RELEASE=$4
HYPERV_VSWITCH=$5
GLANCE_HOST=$6
RPC_BACKEND=$7
RPC_BACKEND_HOST=$8
RPC_BACKEND_USERNAME=$9
RPC_BACKEND_PASSWORD=${10}
QUANTUM_URL=${11}
QUANTUM_ADMIN_AUTH_URL=${12}
QUANTUM_ADMIN_TENANT_NAME=${13}
QUANTUM_KS_PW=${14}

QUANTUM_ADMIN_USERNAME=quantum
GLANCE_PORT=9292
RPC_BACKEND_PORT=5672

BASEDIR=$(dirname $0)

. $BASEDIR/utils.sh

echo "Checking prerequisites"

NOTFOUND=0
pip freeze | grep pywinrm > /dev/null || NOTFOUND=1

if [ "$NOTFOUND" -eq 1 ]; then
    echoerr "pywinrm not found. Install with: sudo pip install --pre pywinrm"
    exit 1
fi

if [ "$RPC_BACKEND" != "RabbitMQ" ] && [ "$RPC_BACKEND" != "ApacheQpid" ]; then
    echoerr "Unsupported RPC backend: $RPC_BACKEND"
    exit 1
fi

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

echo "Downloading Hyper-V OpenStack Compute installer on $HYPERV_COMPUTE_VM_IP"

run_wsmancmd_with_retry $HYPERV_COMPUTE_VM_IP $HYPERV_ADMIN $HYPERV_PASSWORD "powershell -NonInteractive Invoke-WebRequest -Uri http://www.cloudbase.it/downloads/$MSI_FILE -OutFile \$ENV:TEMP\\$MSI_FILE"

echo "Installing Hyper-V OpenStack Compute on $HYPERV_COMPUTE_VM_IP"

if [ "$OPENSTACK_RELEASE" == "grizzly" ]; then
    run_wsmancmd_with_retry $HYPERV_COMPUTE_VM_IP $HYPERV_ADMIN $HYPERV_PASSWORD "msiexec /i %TEMP%\\$MSI_FILE /qn /l*v %TEMP%\\HyperVNovaCompute_setup_log.txt \
    ADDLOCAL=HyperVNovaCompute,QuantumHyperVAgent,iSCSISWInitiator,FreeRDP GLANCEHOST=$GLANCE_HOST GLANCEPORT=$GLANCE_PORT RPCBACKEND=$RPC_BACKEND RPCBACKENDHOST=$RPC_BACKEND_HOST RPCBACKENDPORT=$RPC_BACKEND_PORT \
    RPCBACKENDUSER=$RPC_BACKEND_USERNAME RPCBACKENDPASSWORD=$RPC_BACKEND_PASSWORD INSTANCESPATH=C:\\OpenStack\\Instances ADDVSWITCH=0 VSWITCHNAME=$HYPERV_VSWITCH USECOWIMAGES=1 LOGDIR=C:\\OpenStack\\Log ENABLELOGGING=1 \
    VERBOSELOGGING=1 QUANTUMURL=$QUANTUM_URL QUANTUMADMINTENANTNAME=$QUANTUM_ADMIN_TENANT_NAME QUANTUMADMINUSERNAME=$QUANTUM_ADMIN_USERNAME QUANTUMADMINPASSWORD=$QUANTUM_KS_PW QUANTUMADMINAUTHURL=$QUANTUM_ADMIN_AUTH_URL"
else
    run_wsmancmd_with_retry $HYPERV_COMPUTE_VM_IP $HYPERV_ADMIN $HYPERV_PASSWORD "msiexec /i %TEMP%\\$MSI_FILE /qn /l*v %TEMP%\\HyperVNovaCompute_setup_log.txt \
    ADDLOCAL=HyperVNovaCompute,NeutronHyperVAgent,iSCSISWInitiator,FreeRDP GLANCEHOST=$GLANCE_HOST GLANCEPORT=$GLANCE_PORT RPCBACKEND=$RPC_BACKEND RPCBACKENDHOST=$RPC_BACKEND_HOST RPCBACKENDPORT=$RPC_BACKEND_PORT \
    RPCBACKENDUSER=$RPC_BACKEND_USERNAME RPCBACKENDPASSWORD=$RPC_BACKEND_PASSWORD INSTANCESPATH=C:\\OpenStack\\Instances ADDVSWITCH=0 VSWITCHNAME=$HYPERV_VSWITCH USECOWIMAGES=1 LOGDIR=C:\\OpenStack\\Log ENABLELOGGING=1 \
    VERBOSELOGGING=1 NEUTRONURL=$QUANTUM_URL NEUTRONADMINTENANTNAME=$QUANTUM_ADMIN_TENANT_NAME NEUTRONADMINUSERNAME=$QUANTUM_ADMIN_USERNAME NEUTRONADMINPASSWORD=$QUANTUM_KS_PW NEUTRONADMINAUTHURL=$QUANTUM_ADMIN_AUTH_URL"
fi    

