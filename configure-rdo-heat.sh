#!/bin/bash
set -e

yum install -y "openstack-heat-*" python-heatclient

CONFIG_ROOT_MYSQL_PW=`crudini --get ~/packstack_answers.conf general CONFIG_MYSQL_PW`

QPID_HOST=`crudini --get /etc/nova/nova.conf DEFAULT qpid_hostname`
QPID_USERNAME=`crudini --get /etc/nova/nova.conf DEFAULT qpid_username`
QPID_PASSWORD=`crudini --get /etc/nova/nova.conf DEFAULT qpid_password`

HEAT_DB_PW=Passw0rd
HEAT_USER_PW=Passw0rd
HEAT_HOSTNAME=$QPID_HOST
HEAT_CFN_HOSTNAME=$HEAT_HOSTNAME

crudini --set /etc/heat/heat.conf DEFAULT sql_connection mysql://heat:$HEAT_DB_PW@localhost/heat
heat-db-setup rpm -y -r $CONFIG_ROOT_MYSQL_PW -p $HEAT_DB_PW

keystone user-create --name heat --pass $HEAT_USER_PW
keystone user-role-add --user heat --role admin --tenant services

keystone service-create --name heat-cfn --type cloudformation
HEAT_CFN_SERVICE_ID=`keystone service-get heat-cfn | awk '{if (NR == 5) {print $4}}'`

keystone endpoint-create --region RegionOne --service-id ${HEAT_CFN_SERVICE_ID} --publicurl "http://${HEAT_CFN_HOSTNAME}:8000/v1" --adminurl "http://${HEAT_CFN_HOSTNAME}:8000/v1" --internalurl "http://${HEAT_CFN_HOSTNAME}:8000/v1"

keystone service-create --name heat --type orchestration
HEAT_SERVICE_ID=`keystone service-get heat | awk '{if (NR == 5) {print $4}}'`

keystone endpoint-create --region RegionOne --service-id ${HEAT_SERVICE_ID} --publicurl "http://${HEAT_HOSTNAME}:8004/v1/%(tenant_id)s" --adminurl "http://${HEAT_HOSTNAME}:8004/v1/%(tenant_id)s" --internalurl "http://${HEAT_HOSTNAME}:8004/v1/%(tenant_id)s"

keystone role-create --name heat_stack_user

pushd . && cd /etc/init.d && for s in $(ls openstack-heat-*); do chkconfig $s on && service $s start; done && popd

crudini --set /etc/heat/heat.conf DEFAULT heat_metadata_server_url http://$HEAT_CFN_HOSTNAME:8000
crudini --set /etc/heat/heat.conf DEFAULT heat_waitcondition_server_url http://$HEAT_CFN_HOSTNAME:8000/v1/waitcondition
crudini --set /etc/heat/heat.conf DEFAULT heat_watch_server_url http://$HEAT_CFN_HOSTNAME:8003
#crudini --set /etc/heat/heat.conf DEFAULT debug true
#crudini --set /etc/heat/heat.conf DEFAULT verbose true
crudini --set /etc/heat/heat.conf DEFAULT rpc_backend heat.openstack.common.rpc.impl_qpid
crudini --set /etc/heat/heat.conf DEFAULT qpid_hostname $QPID_HOST
crudini --set /etc/heat/heat.conf DEFAULT qpid_username $QPID_USERNAME
crudini --set /etc/heat/heat.conf DEFAULT qpid_password $QPID_PASSWORD
crudini --set /etc/heat/heat.conf keystone_authtoken admin_tenant_name services
crudini --set /etc/heat/heat.conf keystone_authtoken admin_user heat
crudini --set /etc/heat/heat.conf keystone_authtoken admin_password $HEAT_USER_PW

# Note: had to do this, possibly a bug in the heat RPMs
chown heat.heat /var/log/heat/*

pushd . && cd /etc/init.d && for s in $(ls openstack-heat-*); do chkconfig $s on && service $s start; done && popd



