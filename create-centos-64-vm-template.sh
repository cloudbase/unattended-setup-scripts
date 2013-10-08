#!/bin/sh
BASEDIR=$(dirname $0)

FLOPPY_IMAGE_PATH=$BASEDIR/ks.flp
DATASTORE=datastore1

$BASEDIR/create-vm-template.sh $DATASTORE rhel6-64 centos-6.4-template-40G 1024 40G /vmfs/volumes/datastore2/iso/CentOS-6.4-x86_64-bin-DVD1-ks.iso linux $FLOPPY_IMAGE_PATH "VM Network" true true 

