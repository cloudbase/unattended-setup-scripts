#!/bin/sh
set -e

#TODO: use getops for command line parsing

if [ $# -lt 15 ]; then
    echo "Usage: $0 <datastore> <guest_os> <vm_name> <resource_pool_name> <ram> <vcpus> <vcores> <vmdk_size> <vmdk_template_path> <iso_path> <vmware_tools_iso> <floppy_template_path> <nested_hypervisor_support> <net_adapter_type> <boot_vm> (<port_group_name>)*"
    exit 1
fi

DATASTORE=$1
GUEST_OS=$2
VM_NAME=$3
POOL_NAME=$4
RAM=$5
VCPUS=$6
VCORES=$7
VMDK_SIZE=$8
VMDK_TEMPLATE_PATH=$9
ISO_PATH=$10
VMWARE_TOOLS_ISO=$11
FLOPPY_TEMPLATE_PATH=$12
NESTED_HYPERVISOR=$13
NET_ADAPTER_TYPE=$14
BOOT=$15
FIRST_NETWORK_IDX=16

VMDK_FILE_NAME=$VM_NAME.vmdk
FLOPPY_FILE_NAME=floppy.flp

DATASTORE_PATH=/vmfs/volumes/$DATASTORE
BASE_DIR=${DATASTORE_PATH%%/}/$VM_NAME
VMDK_PATH="${BASE_DIR%%/}/$VMDK_FILE_NAME"
VMX_PATH="${BASE_DIR%%/}/$VM_NAME.vmx" 
FLOPPY_PATH="${BASE_DIR%%/}/$FLOPPY_FILE_NAME" 

VMDK_FORMAT=thin
VMDK_ADAPTER=lsisas

if [ "$POOL_NAME" != "-" ]; then
    POOL_ID=`sed -rn 'N; s/\ +<name>'"$POOL_NAME"'<\/name>\n\ +<objID>(.+)<\/objID>/\1/p' /etc/vmware/hostd/pools.xml`
    if [ -z "$POOL_ID" ]; then
        echo "Resource pool $POOL_NAME not found"
        exit 1
    fi
fi

if [ "$ISO_PATH" != "-" ] && [ ! -f "$ISO_PATH" ]; then
    echo "ISO file $ISO_PATH not found"
    exit 1
fi

if [ "$FLOPPY_TEMPLATE_PATH" != "-" ] && [ ! -f "$FLOPPY_TEMPLATE_PATH" ]; then
    echo "Floppy image file $FLOPPY_TEMPLATE_PATH not found"
    exit 1
fi

mkdir -p $BASE_DIR

if [ "$VMDK_TEMPLATE_PATH" == "-" ]; then
    /sbin/vmkfstools -c $VMDK_SIZE -a $VMDK_ADAPTER -d $VMDK_FORMAT "$VMDK_PATH"
else
    PARENT_FILE_HINT=`grep parentFileNameHint "$VMDK_TEMPLATE_PATH" || EXIT=$?`

    if [ -n "$PARENT_FILE_HINT" ]; then
        # TODO: investigate why when creating a VM with a linked vmdk the base disk gets deleted
        # if the VM is started right after the registration
        BOOT=false
        LINKED_SNAPSHOT=true

        cp "$VMDK_TEMPLATE_PATH" "$VMDK_PATH"

        VMDK_TEMPLATE_DELTA_PATH=${VMDK_TEMPLATE_PATH%.*}-delta.vmdk
        VMDK_DELTA_PATH=${VMDK_PATH%.*}-delta.vmdk
        
        cp "$VMDK_TEMPLATE_DELTA_PATH" "$VMDK_DELTA_PATH"

        # Get the real path, without symlinks
        VMDK_TEMPLATE_PATH_REAL=`readlink -f $VMDK_TEMPLATE_PATH`

        VMDK_TEMPLATE_DIR_ESC=`dirname $VMDK_TEMPLATE_PATH_REAL | sed 's/\//\\\\\//g'`
        sed -i "s/parentFileNameHint=\"/parentFileNameHint=\"$VMDK_TEMPLATE_DIR_ESC\//g" "$VMDK_PATH"  
        
        VMDK_TEMPLATE_DELTA_BASENAME=`basename "$VMDK_TEMPLATE_DELTA_PATH"`
        VMDK_DELTA_BASENAME=`basename "$VMDK_DELTA_PATH"`
        sed -i "s/$VMDK_TEMPLATE_DELTA_BASENAME/$VMDK_DELTA_BASENAME/g" "$VMDK_PATH"
    else
        /sbin/vmkfstools -i "$VMDK_TEMPLATE_PATH" "$VMDK_PATH" -a $VMDK_ADAPTER -d $VMDK_FORMAT
        if [ "$VMDK_SIZE" != "-" ]; then
            /sbin/vmkfstools -X $VMDK_SIZE "$VMDK_PATH"
        fi
    fi
fi

cat << EOF > "$VMX_PATH"
.encoding = "UTF-8"
config.version = "8"
virtualHW.version = "9"
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

if [ "$NESTED_HYPERVISOR" == "true" ]; then
    cat << EOF >> "$VMX_PATH"
vcpu.hotadd = "FALSE"
featMask.vm.hv.capable = "Min:1"
vhv.enable = "TRUE"
EOF
fi

if [ -n "$LINKED_SNAPSHOT" ]; then
    cat << EOF >> "$VMX_PATH"
snapshot.redoNotWithParent = "true"
EOF
fi

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
ethernet$j.virtualDev = "$NET_ADAPTER_TYPE"                                   
ethernet$j.networkName = "$p"                            
ethernet$j.addressType = "generated"
EOF
        j=$((j + 1))
    fi
    i=$((i + 1))
done


VMID=`/bin/vim-cmd solo/registervm "$VMX_PATH" "$VM_NAME" $POOL_ID`
if [ "$BOOT" == "true" ]; then
    /bin/vim-cmd vmsvc/power.on $VMID
fi

echo "VMID: $VMID"

