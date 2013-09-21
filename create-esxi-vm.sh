#!/bin/sh
set -e

DATASTORE=$1
GUEST_OS=$2
VM_NAME=$3
RAM=$4
VCPUS=$5
VCORES=$6
VMDK_SIZE=$7
VMDK_TEMPLATE_PATH=$8
ISO_PATH=$9
VMWARE_TOOLS_ISO=$10
FLOPPY_TEMPLATE_PATH=$11
BOOT=$12
FIRST_NETWORK_IDX=13

VMDK_FILE_NAME=$VM_NAME.vmdk
FLOPPY_FILE_NAME=floppy.flp

DATASTORE_PATH=/vmfs/volumes/$DATASTORE
BASE_DIR=${DATASTORE_PATH%%/}/$VM_NAME
VMDK_PATH="${BASE_DIR%%/}/$VMDK_FILE_NAME"
VMX_PATH="${BASE_DIR%%/}/$VM_NAME.vmx" 
FLOPPY_PATH="${BASE_DIR%%/}/$FLOPPY_FILE_NAME" 

VMDK_FORMAT=thin
VMDK_ADAPTER=lsisas

mkdir -p $BASE_DIR

if [ "$VMDK_TEMPLATE_PATH" == "-" ]; then
    /sbin/vmkfstools -c $VMDK_SIZE -a $VMDK_ADAPTER -d $VMDK_FORMAT "$VMDK_PATH"
else
    # Note: $VMDK_SIZE is ignored
    /sbin/vmkfstools -i "$VMDK_TEMPLATE_PATH" "$VMDK_PATH" -a $VMDK_ADAPTER -d $VMDK_FORMAT
fi

cat << EOF > "$VMX_PATH"
.encoding = "UTF-8"
config.version = "8"
virtualHW.version = "8"
pciBridge0.present = "TRUE"
pciBridge4.present = "TRUE"
pciBridge4.virtualDev = "pcieRootPort"
pciBridge4.functions = "8"
pciBridge5.present = "TRUE"
pciBridge5.virtualDev = "pcieRootPort"
pciBridge5.functions = "8"
pciBridge6.present = "TRUE"
pciBridge6.virtualDev = "pcieRootPort"
pciBridge6.functions = "8"
pciBridge7.present = "TRUE"
pciBridge7.virtualDev = "pcieRootPort"
pciBridge7.functions = "8"
vmci0.present = "TRUE"
hpet0.present = "TRUE"
virtualHW.productCompatibility = "hosted"
powerType.powerOff = "soft"
powerType.powerOn = "hard"
powerType.suspend = "hard"
powerType.reset = "soft"
displayName = "$VM_NAME"
numvcpus = "$VCPUS"
cpuid.coresPerSocket = "$VCORES"
scsi0.present = "TRUE"
scsi0.sharedBus = "none"
scsi0.virtualDev = "lsisas1068"
memsize = "$RAM"
scsi0:0.present = "TRUE"
scsi0:0.fileName = "$VMDK_FILE_NAME"
scsi0:0.deviceType = "scsi-hardDisk"
ide1:0.present = "TRUE"
ide1:0.clientDevice = "FALSE"
ide1:0.deviceType = "cdrom-image"
disk.EnableUUID = "TRUE"
guestOS = "$GUEST_OS"
cleanShutdown = "FALSE"
replay.supported = "FALSE"
softPowerOff = "FALSE"
tools.syncTime = "FALSE"
bios.bootOrder = "hdd,cdrom,floppy"
EOF

if [ "$ISO_PATH" != "-" ]; then
    cat << EOF >> "$VMX_PATH" 
ide1:0.startConnected = "TRUE" 
ide1:0.fileName = "$ISO_PATH"
EOF
fi

if [ "$VMWARE_TOOLS_ISO" != "-" ]; then
    cat << EOF >> "$VMX_PATH"
ide1:1.present = "TRUE"
ide1:1.clientDevice = "FALSE"
ide1:1.deviceType = "cdrom-image"
ide1:1.startConnected = "TRUE"
ide1:1.fileName = "/usr/lib/vmware/isoimages/$VMWARE_TOOLS_ISO.iso"
EOF
fi

if [ "$FLOPPY_TEMPLATE_PATH" != "-" ]; then
    cp "$FLOPPY_TEMPLATE_PATH" "$FLOPPY_PATH" 
    cat << EOF >> "$VMX_PATH"
floppy0.present = "TRUE"
floppy0.fileType = "file"
floppy0.clientDevice = "FALSE"
floppy0.fileName="$FLOPPY_FILE_NAME"
EOF
fi

i=1
j=0
for p in "$@"
do
    if [[ $i -gt $FIRST_NETWORK_IDX || $i -eq $FIRST_NETWORK_IDX ]]; then
            cat << EOF >> "$VMX_PATH"
ethernet$j.present = "TRUE"                                        
ethernet$j.virtualDev = "e1000e"                                   
ethernet$j.networkName = "$p"                            
ethernet$j.addressType = "generated"
EOF
        j=$((j + 1))
    fi
    i=$((i + 1))
done


VMID=`/bin/vim-cmd solo/registervm "$VMX_PATH"`
if [ "$BOOT" == "true" ]; then
    /bin/vim-cmd vmsvc/power.on $VMID
fi

#/bin/vim-cmd vmsvc/tools.install $VMID

