#!/bin/bash
set -e

EXT_IFACE=eth0
INT_IFACE=eth1

INT_IFACE_ADDR=10.66.0.1
INT_IFACE_MASK=255.255.0.0
INT_IFACE_MASK_BITS=16
INT_IFACE_NETWORK=10.66.0.0

DOMAIN_NAME=cbstest.local
DOMAIN_NAME_SERVERS="8.8.8.8, 8.8.4.4"
SUBNET=$INT_IFACE_NETWORK
RANGE_START=10.66.0.2
RANGE_END=10.66.254.254
MASK=$INT_IFACE_MASK
ROUTER=$INT_IFACE_ADDR

PROXY_PORT=8080
APT_CACHER_PORT=3142
HTTP_PORT=8081

APT_CACHER_ADMIN=admin
APT_CACHER_ADMIN_PASSWORD=Passw0rd

cat << EOF > /etc/network/interfaces
auto lo
iface lo inet loopback

auto $EXT_IFACE
iface $EXT_IFACE inet dhcp

auto $INT_IFACE
iface $INT_IFACE inet static
    address $INT_IFACE_ADDR
    netmask $INT_IFACE_MASK
    network $INT_IFACE_NETWORK
EOF

/etc/init.d/networking restart


sed -i 's/^DEFAULT_FORWARD_POLICY=.*$/DEFAULT_FORWARD_POLICY="ACCEPT"/g' /etc/default/ufw

sed -i 's/^#net\/ipv4\/ip_forward=.*$/net\/ipv4\/ip_forward=1/g' /etc/ufw/sysctl.conf
sed -i 's/^#net\/ipv6\/conf\/default\/forwarding=.*$/net\/ipv6\/conf\/default\/forwarding=1/g' /etc/ufw/sysctl.conf

sed -i "s/^# Don't delete these required lines, otherwise there will be errors$/*nat\n:POSTROUTING ACCEPT \[0:0\]\n-A POSTROUTING -s $INT_IFACE_NETWORK\/$INT_IFACE_MASK_BITS -o $EXT_IFACE -j MASQUERADE\nCOMMIT\n\n# Don't delete these required lines, otherwise there will be errors\n/g" /etc/ufw/before.rules

function add_module {
    /sbin/modprobe $1
    echo $1 >> /etc/modules
}

add_module ip_tables
add_module nf_conntrack
add_module nf_conntrack_ftp
add_module nf_conntrack_irc
add_module iptable_nat
add_module nf_nat_ftp

ufw allow 22
ufw disable && sudo ufw --force enable
/sbin/sysctl -p

apt-get -y install isc-dhcp-server

sed -i "s/^INTERFACES=.*$/INTERFACES=\"$INT_IFACE\"/g" /etc/default/isc-dhcp-server

sed -i "s/^option domain-name .*;$/option domain-name \"$DOMAIN_NAME\";/g" /etc/dhcp/dhcpd.conf
sed -i "s/^option domain-name-servers .*;$/option domain-name-servers $DOMAIN_NAME_SERVERS;/g" /etc/dhcp/dhcpd.conf
sed -i "s/^#authoritative;$/authoritative;/g" /etc/dhcp/dhcpd.conf

cat << EOF >> /etc/dhcp/dhcpd.conf
option custom-proxy-server code 252 = text;

subnet $SUBNET netmask $MASK {
    range $RANGE_START $RANGE_END;
    option routers $ROUTER;
    option ntp-servers pool.ntp.org;
    option custom-proxy-server "http://$INT_IFACE_ADDR:$HTTP_PORT/wpad.dat";
}

EOF

service isc-dhcp-server restart

apt-get -y install apt-cacher-ng/precise-backports
echo "AdminAuth: $APT_CACHER_ADMIN:$APT_CACHER_ADMIN_PASSWORD" >> /etc/apt-cacher-ng/security.conf
/etc/init.d/apt-cacher-ng restart
# apt-cacher-ng web UI
ufw allow $APT_CACHER_PORT


apt-get -y install squid

cat << EOF > /etc/squid3/squid.conf
acl manager proto cache_object
acl localhost src 127.0.0.1/32 ::1
acl to_localhost dst 127.0.0.0/8 0.0.0.0/32 ::1
acl SSL_ports port 443
acl Safe_ports port 80      # http
acl Safe_ports port 21      # ftp
acl Safe_ports port 443     # https
acl Safe_ports port 70      # gopher
acl Safe_ports port 210     # wais
acl Safe_ports port 1025-65535  # unregistered ports
acl Safe_ports port 280     # http-mgmt
acl Safe_ports port 488     # gss-http
acl Safe_ports port 591     # filemaker
acl Safe_ports port 777     # multiling http
acl CONNECT method CONNECT
acl internal_network src $INT_IFACE_NETWORK/$INT_IFACE_MASK_BITS

acl windowsupdate dstdomain windowsupdate.microsoft.com
acl windowsupdate dstdomain .update.microsoft.com
acl windowsupdate dstdomain download.windowsupdate.com
acl windowsupdate dstdomain redir.metaservices.microsoft.com
acl windowsupdate dstdomain images.metaservices.microsoft.com
acl windowsupdate dstdomain c.microsoft.com
acl windowsupdate dstdomain www.download.windowsupdate.com
acl windowsupdate dstdomain wustat.windows.com
acl windowsupdate dstdomain crl.microsoft.com
acl windowsupdate dstdomain sls.microsoft.com
acl windowsupdate dstdomain productactivation.one.microsoft.com
acl windowsupdate dstdomain ntservicepack.microsoft.com
acl wuCONNECT dstdomain www.update.microsoft.com
acl wuCONNECT dstdomain sls.microsoft.com

# Make sure to have enough disk space for the cache (60GB)
cache_dir ufs /var/spool/squid3 61440 16 256

range_offset_limit 4000 MB windowsupdate
maximum_object_size 4000 MB
quick_abort_min -1

cache_peer localhost parent $APT_CACHER_PORT 7 proxy-only no-query no-netdb-exchange connect-timeout=15
acl aptget browser -i apt-get apt-http apt-cacher apt-proxy yum
acl deburl urlpath_regex /(Packages|Sources|Release|Translations-.*)\(.(gpg|gz|bz2))?$ /pool/.*/.deb$ /(Sources|Packages).diff/ /dists/[^/]*/[^/]*/(binary-.*|source)/.
cache_peer_access localhost allow aptget
cache_peer_access localhost allow deburl
cache_peer_access localhost deny all

http_access allow manager localhost
http_access deny manager
http_access deny !Safe_ports
http_access deny CONNECT !SSL_ports

http_access allow localhost
http_access allow internal_network

http_access allow CONNECT wuCONNECT internal_network
http_access allow CONNECT wuCONNECT localhost
http_access allow windowsupdate internal_network
http_access allow windowsupdate localhost

http_access deny all

http_port $PROXY_PORT transparent

coredump_dir /var/spool/squid3

refresh_pattern -i .*microsoft\.com/.*\.(cab|exe|ms[i|u|f]|asf|wm[v|a]|dat|zip|psf) 129600 100% 129600 override-expire override-lastmod reload-into-ims ignore-reload ignore-no-cache ignore-private
refresh_pattern -i .*windowsupdate\.com/.*\.(cab|exe|ms[i|u|f]|asf|wm[v|a]|dat|zip|psf) 129600 100% 129600 override-expire override-lastmod reload-into-ims ignore-reload ignore-no-cache ignore-private
refresh_pattern -i .*windows\.com/.*\.(cab|exe|ms[i|u|f]|asf|wm[v|a]|dat|zip|psf) 129600 100% 129600 override-expire override-lastmod reload-into-ims ignore-reload ignore-no-cache ignore-private

refresh_pattern ^ftp:       1440    20% 10080
refresh_pattern ^gopher:    1440    0%  1440
refresh_pattern -i (/cgi-bin/|\?) 0 0%  0
refresh_pattern (Release|Packages(.gz)*)$      0       20%     2880
refresh_pattern .       0   20% 4320
EOF

/usr/sbin/service squid3 restart

sed -i "s/^*nat$/*nat\n-A PREROUTING -i eth1 -p tcp -m tcp --dport 80 -j DNAT --to-destination $INT_IFACE_ADDR:$PROXY_PORT\n-A PREROUTING -i eth1 -p tcp -m tcp --dport 80 -j REDIRECT --to-ports $PROXY_PORT/g" /etc/ufw/before.rules

# Allow on internal interface only
ufw allow in on $INT_IFACE to any port $PROXY_PORT proto tcp
ufw disable && sudo ufw --force enable

apt-get -y install apache2

sed -i "s/^NameVirtualHost .*$/NameVirtualHost \*:$HTTP_PORT/g" /etc/apache2/ports.conf
sed -i "s/^Listen .*$/Listen $HTTP_PORT/g" /etc/apache2/ports.conf
sed -i "s/^<VirtualHost .*>$/<VirtualHost \*:$HTTP_PORT>/g" /etc/apache2/sites-available/default

/usr/sbin/service apache2 restart

# Allow on internal interface only
ufw allow in on $INT_IFACE to any port $HTTP_PORT proto tcp

cat << EOF > /var/www/wpad.dat
function FindProxyForURL(url, host)
{
    return "PROXY $INT_IFACE_ADDR:$PROXY_PORT; DIRECT";
}
EOF

cat << EOF >> /var/www/.htaccess
AddType application/x-ns-proxy-autoconfig .dat
EOF
