#!/bin/sh
set -e

BASEDIR=$(dirname $0)
source $BASEDIR/config
FLOPPY_IMAGE_PATH=$BASEDIR/unattend_hyperv_2012_cloudbaseinit.flp
ISO_PATH=/vmfs/volumes/$ISO_DATASTORE/$ISO_DIR/cn_microsoft_hyper-v_server_2012_x64_dvd_915786.iso
SIZE=100G

$BASEDIR/create-vm-template.sh $TEMPLATES_DATASTORE winhyperv hyperv-2012-cn-template-$SIZE 2048 $SIZE "$ISO_PATH" windows "$FLOPPY_IMAGE_PATH" "VM Network" true true
 
