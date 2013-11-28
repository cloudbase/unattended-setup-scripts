#!/bin/sh
set -e

BASEDIR=$(dirname $0)
source $BASEDIR/config
FLOPPY_IMAGE_PATH=$BASEDIR/unattend_windows_8.1_ent_cloudbaseinit.flp
ISO_PATH=/vmfs/volumes/$ISO_DATASTORE/$ISO_DIR/en_windows_8_1_enterprise_x64_dvd_2791088.iso
SIZE=20G

$BASEDIR/create-vm-template.sh $TEMPLATES_DATASTORE winhyperv windows-8.1-ent-template-$SIZE 2048 $SIZE "$ISO_PATH" windows "$FLOPPY_IMAGE_PATH" "VM Network" true true

