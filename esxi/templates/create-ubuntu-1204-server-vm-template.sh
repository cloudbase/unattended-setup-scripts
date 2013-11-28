#!/bin/sh
set -e

BASEDIR=$(dirname $0)
source $BASEDIR/config
FLOPPY_IMAGE_PATH=$BASEDIR/preseed.flp
ISO_PATH=/vmfs/volumes/$ISO_DATASTORE/$ISO_DIR/ubuntu-12.04.3-server-amd64-preseed.iso
SIZE=100G

$BASEDIR/create-vm-template.sh $TEMPLATES_DATASTORE ubuntu-64 ubuntu-12.04-server-template-$SIZE 1024 $SIZE "$ISO_PATH" linux "$FLOPPY_IMAGE_PATH" "VM Network" true true 

