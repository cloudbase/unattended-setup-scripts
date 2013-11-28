#!/bin/sh
set -e

BASEDIR=$(dirname $0)
source $BASEDIR/config
FLOPPY_IMAGE_PATH=$BASEDIR/unattend_hyperv_2012_r2_cloudbaseinit.flp
ISO_PATH=/vmfs/volumes/$ISO_DATASTORE/$ISO_DIR/en_microsoft_hyper-v_server_2012_r2_x64_dvd_2708236.iso
SIZE=100G

$BASEDIR/create-vm-template.sh $TEMPLATES_DATASTORE winhyperv hyperv-2012-r2-template-$SIZE 2048 $SIZE "$ISO_PATH" windows "$FLOPPY_IMAGE_PATH" "VM Network" true true

