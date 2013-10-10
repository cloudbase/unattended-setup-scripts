#!/bin/bash
set -e

wget http://dev.centos.org/centos/hyper-v/CentOS-6.4-x86_64-Minimal-OpenStack.image.qcow2.bz2
bunzip2 CentOS-6.4-x86_64-Minimal-OpenStack.image.qcow2.bz2
glance image-create --name="CentOS-6.4-x86_64-Minimal-OpenStack" --disk-format=qcow2 --container-format=bare --property hypervisor_type=qemu < CentOS-6.4-x86_64-Minimal-OpenStack.image.qcow2

mkdir -p ~/.ssh
nova keypair-add key1 > ~/.ssh/id_rsa
chmod 600 ~/.ssh/id_rsa

NETID1=`quantum net-create net1 | awk '{if (NR == 6) {print $4}}'`
SUBNETID1=`quantum subnet-create net1 10.0.1.0/24 --dns_nameservers list=true 8.8.8.8 | awk '{if (NR == 11) {print $4}}'`

ROUTERID1=`quantum router-create router1 | awk '{if (NR == 7) {print $4}}'`

quantum router-interface-add $ROUTERID1 $SUBNETID1

EXTNETID1=`quantum net-create ext_net --router:external=True | awk '{if (NR == 6) {print $4}}'`
quantum subnet-create ext_net --allocation-pool start=10.7.201.50,end=10.7.201.200 --gateway 10.7.1.1 10.7.0.0/16 --enable_dhcp=False

quantum router-gateway-set $ROUTERID1 $EXTNETID1

NETID1=`quantum net-show net1 | awk '{if (NR == 5) {print $4}}'`
nova boot  --flavor 1 --image "CentOS-6.4-x86_64-Minimal-OpenStack" --key-name key1 --nic net-id=$NETID1 vm1

