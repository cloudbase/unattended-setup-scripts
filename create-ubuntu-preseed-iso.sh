SO_DEST_TMP=`mktemp -d`#!/bin/bash
set -e

if [ $# -ne 2 ]; then
    echo "Usage: $0 <source_ISO> <dest_ISO>"
    exit 1
fi

if [ $EUID -ne 0 ]; then
    echo "This script must be run as root" 1>&2
    exit 1
fi

ISO_SRC=$1
ISO_DEST=$2

ISO_SRC_TMP=`mktemp -d`
ISO_DEST_TMP=`mktemp -d`

echo "Mounting $ISO_SRC..."
mount -o ro,loop $ISO_SRC $ISO_SRC_TMP

# Preserve the ISO label
ISO_LABEL=`blkid -o value $ISO_SRC | awk 'NR == 1'`

echo "Copying $ISO_SRC contents..."
cp -a -r $ISO_SRC_TMP/. $ISO_DEST_TMP

umount $ISO_SRC_TMP
rmdir $ISO_SRC_TMP

echo $ISO_DEST_TMP

ISOLINUXCFG=$ISO_DEST_TMP/isolinux/isolinux.cfg

cat << EOF > $ISOLINUXCFG
# D-I config version 2.0
prompt 0
timeout 0

default preseed
label preseed
  menu label ^Preseed
  kernel /install/vmlinuz
  append  file=/floppy/preseed.cfg debian-installer/locale=en_US console-setup/layoutcode=us keyboard-configuration/modelcode=pc105 keyboard-configuration/layoutcode=us vga=788 initrd=/install/initrd.gz quiet --
EOF

echo "Creating $ISO_DEST..."
mkisofs -o $ISO_DEST -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -R -J -V "$ISO_LABEL" -T -quiet $ISO_DEST_TMP
rm -rf $ISO_DEST_TMP
 
