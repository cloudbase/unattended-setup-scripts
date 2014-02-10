#!/bin/bash
set -e

# Tested on Ubuntu Server 12.04

sudo apt-get install -y pkg-config uuid-dev libglib2.0 autoconf zlib1g-dev libtool

QEMU_DIR=qemu-1.7.0
QEMU_SRC=$QEMU_DIR.tar.bz2

wget http://wiki.qemu-project.org/download/$QEMU_SRC
tar jxf $QEMU_SRC

pushd .
cd $QEMU_DIR
# target-list is here just to limit the amount of stuff to compile
./configure --enable-uuid --enable-vhdx --target-list=x86_64-linux-user
make
# Avoid installing everything, just install qemu-img
#make install
popd

QEMU_IMG=`which qemu-img`

if [ -f "$QEMU_IMG" ]; then
    sudo mv -f $QEMU_IMG $QEMU_IMG.old
    sudo cp -f $QEMU_DIR/qemu-img $QEMU_IMG
fi
