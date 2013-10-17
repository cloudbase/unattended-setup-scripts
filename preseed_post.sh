#!/bin/bash
set -e

/usr/bin/apt-get update -y
/usr/bin/apt-get upgrade -y

CDROM_DEV=/dev/cdrom
CDROM_LABEL=`blkid -o value $CDROM_DEV | awk 'NR == 1'`
if [ "$CDROM_LABEL" != "VMware Tools" ]; then
    CDROM_DEV=/dev/cdrom1
fi

TMP1=`mktemp -d`
mount -o ro $CDROM_DEV $TMP1
TMP2=`mktemp -d`
cd $TMP2
tar zxf $TMP1/VMwareTools-*
umount $TMP1
rmdir $TMP1
cd vmware-tools-distrib/
./vmware-install.pl --default
rm -rf $TMP2

