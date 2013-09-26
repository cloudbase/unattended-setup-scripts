#!/bin/sh
BASEDIR=$(dirname $0)

FLOPPY_IMAGE_PATH=$BASEDIR/ks.flp
DATASTORE=datastore1

$BASEDIR/create-vm-template.sh $DATASTORE rhel6-64 centos-6.4-template 1024 10G /vmfs/volumes/datastore2/iso/CentOS-6.4-x86_64-bin-DVD1.iso linux $FLOPPY_IMAGE_PATH "VM Network" 

