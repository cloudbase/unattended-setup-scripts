#!/bin/bash
set -e

if [ $# -ne 20 ]; then
    echo "Usage: $0 <hyperv_host_ip> <hyperv_admin_username> <hyperv_password> <openstack_release> <vswitch_name> <glance_host> \
<rpc_backend> <rpc_backend_host> <rpc_backend_username> <rpc_backend_password> <neutron_url> \
<neutron_admin_auth_url> <neutron_admin_tenant_name> <neutron_admin_username> <neutron_admin_password> \
<ceilometer_admin_auth_url> <ceilometer_admin_tenant_name> <ceilometer_admin_username> <ceilometer_admin_password> \
<ceilometer_metering_secret>"
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
NEUTRON_URL=${11}
NEUTRON_ADMIN_AUTH_URL=${12}
NEUTRON_ADMIN_TENANT_NAME=${13}
NEUTRON_ADMIN_USERNAME=${14}
NEUTRON_ADMIN_PASSWORD=${15}
CEILOMETER_ADMIN_AUTH_URL=${16}
CEILOMETER_ADMIN_TENANT_NAME=${17}
CEILOMETER_ADMIN_USERNAME=${18}
CEILOMETER_ADMIN_PASSWORD=${19}
CEILOMETER_METERING_SECRET=${20}

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
elif [ "$OPENSTACK_RELEASE" == "havana" ]; then
    MSI_FILE=HyperVNovaCompute_Havana.msi
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

HYPERV_FEATURES="HyperVNovaCompute,iSCSISWInitiator,FreeRDP"

if [ "$OPENSTACK_RELEASE" == "grizzly" ]; then
    if [ -n "$NEUTRON_ADMIN_AUTH_URL" ]; then
        HYPERV_FEATURES+=",QuantumHyperVAgent"
    fi

    run_wsmancmd_with_retry $HYPERV_COMPUTE_VM_IP $HYPERV_ADMIN $HYPERV_PASSWORD "msiexec /i %TEMP%\\$MSI_FILE /qn /l*v %TEMP%\\HyperVNovaCompute_setup_log.txt \
    ADDLOCAL=$HYPERV_FEATURES GLANCEHOST=$GLANCE_HOST GLANCEPORT=$GLANCE_PORT RPCBACKEND=$RPC_BACKEND \
    RPCBACKENDHOST=$RPC_BACKEND_HOST RPCBACKENDPORT=$RPC_BACKEND_PORT RPCBACKENDUSER=$RPC_BACKEND_USERNAME RPCBACKENDPASSWORD=$RPC_BACKEND_PASSWORD \
    INSTANCESPATH=C:\\OpenStack\\Instances ADDVSWITCH=0 VSWITCHNAME=$HYPERV_VSWITCH USECOWIMAGES=1 LOGDIR=C:\\OpenStack\\Log ENABLELOGGING=1 \
    VERBOSELOGGING=1 QUANTUMURL=$NEUTRON_URL QUANTUMADMINTENANTNAME=$NEUTRON_ADMIN_TENANT_NAME QUANTUMADMINUSERNAME=$NEUTRON_ADMIN_USERNAME \
    QUANTUMADMINPASSWORD=$NEUTRON_ADMIN_PASSWORD QUANTUMADMINAUTHURL=$NEUTRON_ADMIN_AUTH_URL"
else
    if [ -n "$NEUTRON_ADMIN_AUTH_URL" ]; then
        HYPERV_FEATURES+=",NeutronHyperVAgent"
    fi

    if [ -n "$CEILOMETER_ADMIN_AUTH_URL" ]; then
        HYPERV_FEATURES+=",CeilometerComputeAgent"
    fi

    run_wsmancmd_with_retry $HYPERV_COMPUTE_VM_IP $HYPERV_ADMIN $HYPERV_PASSWORD "msiexec /i %TEMP%\\$MSI_FILE /qn /l*v %TEMP%\\HyperVNovaCompute_setup_log.txt \
    ADDLOCAL=$HYPERV_FEATURES GLANCEHOST=$GLANCE_HOST GLANCEPORT=$GLANCE_PORT RPCBACKEND=$RPC_BACKEND \
    RPCBACKENDHOST=$RPC_BACKEND_HOST RPCBACKENDPORT=$RPC_BACKEND_PORT RPCBACKENDUSER=$RPC_BACKEND_USERNAME RPCBACKENDPASSWORD=$RPC_BACKEND_PASSWORD \
    INSTANCESPATH=C:\\OpenStack\\Instances ADDVSWITCH=0 VSWITCHNAME=$HYPERV_VSWITCH USECOWIMAGES=1 LOGDIR=C:\\OpenStack\\Log ENABLELOGGING=1 \
    VERBOSELOGGING=1 NEUTRONURL=$NEUTRON_URL NEUTRONADMINTENANTNAME=$NEUTRON_ADMIN_TENANT_NAME NEUTRONADMINUSERNAME=$NEUTRON_ADMIN_USERNAME \
    NEUTRONADMINPASSWORD=$NEUTRON_ADMIN_PASSWORD NEUTRONADMINAUTHURL=$NEUTRON_ADMIN_AUTH_URL \
    CEILOMETERADMINTENANTNAME=$CEILOMETER_ADMIN_TENANT_NAME CEILOMETERADMINUSERNAME=$CEILOMETER_ADMIN_USERNAME \
    CEILOMETERADMINPASSWORD=$CEILOMETER_ADMIN_PASSWORD CEILOMETERADMINAUTHURL=$CEILOMETER_ADMIN_AUTH_URL \
    CEILOMETERMETERINGSECRET=$CEILOMETER_METERING_SECRET"
fi
