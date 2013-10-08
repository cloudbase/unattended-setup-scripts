#!/bin/sh

BASEDIR=$(dirname $0)
DATASTORE=datastore1
FLOPPY_IMAGE_PATH=$BASEDIR/unattend_hyperv_2012_r2_cloudbaseinit.flp

$BASEDIR/create-vm-template.sh $DATASTORE winhyperv hyperv-2012-r2-template-80G 2048 80G /vmfs/volumes/datastore2/iso/en_microsoft_hyper-v_server_2012_r2_x64_dvd_2708236.iso windows $FLOPPY_IMAGE_PATH "VM Network" true true 

