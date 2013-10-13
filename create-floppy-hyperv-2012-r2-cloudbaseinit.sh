#!/bin/bash

BASEDIR=$(dirname $0)

TMP_AUTOUNATTEND_FILE=/tmp/Autounattend.xml

cp $BASEDIR/Autounattend.xml $TMP_AUTOUNATTEND_FILE
sed -i 's/%IMAGENAME%/Hyper-V Server 2012 R2 SERVERHYPERCORE/g' $TMP_AUTOUNATTEND_FILE

$BASEDIR/create-floppy.sh $BASEDIR/unattend_hyperv_2012_r2_cloudbaseinit.flp $TMP_AUTOUNATTEND_FILE
rm $TMP_AUTOUNATTEND_FILE

