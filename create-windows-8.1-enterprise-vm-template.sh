#!/bin/sh

BASEDIR=$(dirname $0)
DATASTORE=datastore1
FLOPPY_IMAGE_PATH=$BASEDIR/unattend_windows_8.1_ent_cloudbaseinit.flp

$BASEDIR/create-vm-template.sh $DATASTORE winhyperv windows-8.1-ent-template 2048 20G /vmfs/volumes/datastore2/iso/en_windows_8_1_enterprise_x64_dvd_2791088.iso windows $FLOPPY_IMAGE_PATH "VM Network" true true 

