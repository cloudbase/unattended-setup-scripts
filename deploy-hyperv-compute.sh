#!/bin/bash
set -e

if [ $# -ne 13 ]; then
    echo "Usage: $0 <hyperv_host_ip> <hyperv_host_name> <hyperv_admin_username> <hyperv_password> <vswitch_name> <glance_host> <qpid_host> <qpid_username> <qpid_password> <quantum_url> <quantum_admin_auth_url> <quantum_admin_tenant_name> <quantum_admin_password>"
    exit 1
fi

HYPERV_COMPUTE_VM_IP=$1
HYPERV_COMPUTE_VM_NAME=$2
HYPERV_ADMIN=$3
HYPERV_PASSWORD=$4
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

echo "Configuring external virtual switch on Hyper-V"

exec_with_retry "$BASEDIR/create-hyperv-external-vswitch.sh $HYPERV_COMPUTE_VM_IP $HYPERV_ADMIN $HYPERV_PASSWORD $HYPERV_VSWITCH"

echo "Deploy Hyper-V OpenStack components on $HYPERV_COMPUTE_VM_IP"

MSI_FILE=HyperVNovaCompute_Grizzly.msi

run_wsmancmd_with_retry $HYPERV_COMPUTE_VM_IP $HYPERV_ADMIN $HYPERV_PASSWORD "powershell -NonInteractive Invoke-WebRequest -Uri http://www.cloudbase.it/downloads/$MSI_FILE -OutFile \$ENV:TEMP\\$MSI_FILE"

run_wsmancmd_with_retry $HYPERV_COMPUTE_VM_IP $HYPERV_ADMIN $HYPERV_PASSWORD "msiexec /i %TEMP%\\$MSI_FILE /qn /l*v %TEMP%\\HyperVNovaCompute_setup_log.txt \
ADDLOCAL=HyperVNovaCompute,QuantumHyperVAgent,iSCSISWInitiator,FreeRDP GLANCEHOST=$GLANCE_HOST GLANCEPORT=$GLANCE_PORT RPCBACKEND=ApacheQpid RPCBACKENDHOST=$QPID_HOST RPCBACKENDPORT=$QPID_PORT \
RPCBACKENDUSER=$QPID_USERNAME RPCBACKENDPASSWORD=$QPID_PASSWORD INSTANCESPATH=C:\\OpenStack\\Instances ADDVSWITCH=0 VSWITCHNAME=$HYPERV_VSWITCH USECOWIMAGES=1 LOGDIR=C:\\OpenStack\\Log ENABLELOGGING=1 \
VERBOSELOGGING=1 QUANTUMURL=$QUANTUM_URL QUANTUMADMINTENANTNAME=$QUANTUM_ADMIN_TENANT_NAME QUANTUMADMINUSERNAME=$QUANTUM_ADMIN_USERNAME QUANTUMADMINPASSWORD=$QUANTUM_KS_PW QUANTUMADMINAUTHURL=$QUANTUM_ADMIN_AUTH_URL"

echo "Renaming and rebooting Hyper-V host $HYPERV_COMPUTE_VM_IP"

run_wsmancmd_with_retry $HYPERV_COMPUTE_VM_IP $HYPERV_ADMIN $HYPERV_PASSWORD 'powershell -NonInteractive -Command "if ([System.Net.Dns]::GetHostName() -ne \"'$HYPERV_COMPUTE_VM_NAME'\") { Rename-Computer \"'$HYPERV_COMPUTE_VM_NAME'\" -Restart -Force }"'

#run_wsmancmd_with_retry $HYPERV_COMPUTE_VM_IP $HYPERV_ADMIN $HYPERV_PASSWORD "powershell Rename-Computer $HYPERV_COMPUTE_VM_NAME -Restart -Force"

#echo "Rebooting Hyper-V host $HYPERV_COMPUTE_VM_IP"
#run_wsmancmd_with_retry $HYPERV_COMPUTE_VM_IP $HYPERV_ADMIN $HYPERV_PASSWORD  "shutdown /r /t 0"


