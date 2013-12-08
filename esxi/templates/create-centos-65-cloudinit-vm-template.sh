#!/bin/sh
set -e

BASEDIR=$(dirname $0)
source $BASEDIR/config
FLOPPY_IMAGE_PATH=$BASEDIR/ks_cloudinit.flp
ISO_PATH=/vmfs/volumes/$ISO_DATASTORE/$ISO_DIR/CentOS-6.4-x86_64-bin-DVD1-ks.iso
SIZE=10G

$BASEDIR/create-vm-template.sh $TEMPLATES_DATASTORE rhel6-64 centos-6.5-cloudinit-template-$SIZE 1024 $SIZE "$ISO_PATH" linux "$FLOPPY_IMAGE_PATH" "VM Network" true true 

