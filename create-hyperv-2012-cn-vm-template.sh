#!/bin/sh

BASEDIR=$(dirname $0)
DATASTORE=datastore1
FLOPPY_IMAGE_PATH=$BASEDIR/unattend_hyperv_2012_cloudbaseinit.flp
ISO_PATH=/vmfs/volumes/datastore2/iso/cn_microsoft_hyper-v_server_2012_x64_dvd_915786.iso

$BASEDIR/create-vm-template.sh $DATASTORE winhyperv hyperv-2012-cn-template-80G 2048 80G $ISO_PATH windows $FLOPPY_IMAGE_PATH "VM Network" true true 

