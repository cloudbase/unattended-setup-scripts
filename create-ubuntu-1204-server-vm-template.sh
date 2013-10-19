#!/bin/sh
BASEDIR=$(dirname $0)

ISO_PATH=/vmfs/volumes/datastore2/iso/ubuntu-12.04.3-server-amd64-preseed.iso
FLOPPY_IMAGE_PATH=$BASEDIR/preseed.flp
DATASTORE=datastore1

$BASEDIR/create-vm-template.sh $DATASTORE ubuntu-64 ubuntu-12.04-server-template-40G 1024 40G $ISO_PATH linux $FLOPPY_IMAGE_PATH "VM Network" true true 

