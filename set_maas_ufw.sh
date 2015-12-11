#!/bin/bash
set -e

MAAS_ADMIN_IFACE=eth0
MAAS_NODES_IFACE=eth1

sudo apt-get install ufw -y

# optionally, if you want to start with a clean config:
# sudo ufw --force reset

sudo ufw --force enable

# At the end of /etc/ufw/before.rules

# Replace the last COMMIT line with the following content,
# matching your IP range and interfaces:

#-A ufw-before-forward -i eth1 -o eth0 -j ACCEPT
#
#COMMIT
#
## nat Table rules
#*nat
#:POSTROUTING ACCEPT [0:0]
#
#-A POSTROUTING -s 10.41.41.0/24 -o eth0 -j MASQUERADE
#
# don't delete the 'COMMIT' line or these rules won't be processed
#COMMIT

# Edit /etc/ufw/sysctl.conf and set:
#net/ipv4/ip_forward=1
#net/ipv6/conf/default/forwarding=1
#net/ipv6/conf/all/forwarding=1

sudo ufw default deny incoming
sudo ufw default allow outgoing

# SSH
sudo ufw allow in on $MAAS_ADMIN_IFACE proto tcp from any to any port 22


# DHCP
sudo ufw allow in on $MAAS_NODES_IFACE proto udp from any to any port 67

# DNS
sudo ufw allow in on $MAAS_NODES_IFACE proto udp from any to any port 53
sudo ufw allow in on $MAAS_NODES_IFACE proto tcp from any to any port 53

# TFTP
sudo ufw allow in on $MAAS_NODES_IFACE proto udp from any to any port 69

# iSCSI target
sudo ufw allow in on $MAAS_NODES_IFACE proto tcp from any to any port 3260

# Squid
sudo ufw allow in on $MAAS_NODES_IFACE proto tcp from any to any port 3128
sudo ufw allow in on $MAAS_NODES_IFACE proto tcp from any to any port 8000

# MaaS UI
sudo ufw allow in on $MAAS_ADMIN_IFACE proto tcp from any to any port 80

# From region controller to cluster controllers
sudo ufw allow in on $MAAS_ADMIN_IFACE proto tcp from any to any port 7911

# PostgreSQL, enable for replication
sudo ufw allow in on $MAAS_ADMIN_IFACE proto tcp from any to any port 5432

# MaaS Twister
sudo ufw allow in on $MAAS_NODES_IFACE proto tcp from any to any port 5240
sudo ufw allow in on $MAAS_NODES_IFACE proto tcp from any to any port 5248
sudo ufw allow in on $MAAS_NODES_IFACE proto tcp from any to any port 5250
sudo ufw allow in on $MAAS_NODES_IFACE proto tcp from any to any port 5251
sudo ufw allow in on $MAAS_NODES_IFACE proto tcp from any to any port 5252
sudo ufw allow in on $MAAS_NODES_IFACE proto tcp from any to any port 5253

# Restart firewall
sudo service ufw restart

