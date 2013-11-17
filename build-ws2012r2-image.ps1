$ErrorActionPreference = "Stop"

$vmname = "OpenStack WS 2012 R2 Standard Evaluation"
$vhdpath = "C:\VM\windows-server-2012-r2.vhd"
$isoPath = "C:\ISO\9600.16384.WINBLUE_RTM.130821-1623_X64FRE_SERVER_EVAL_EN-US-IRM_SSS_X64FREE_EN-US_DV5.ISO"
$floppyPath = "C:\tools\Autounattend.vfd"
$vmSwitch = "external2"

$vm = (Get-VM | where {$_.Name -eq $vmname })
if ($vm) {
    if ($vm.State -ne "Off") {
        $vm | Stop-VM -Force
    }
    $vm | Remove-VM -Force
}

if(Test-Path $vhdpath) {
    del $vhdpath
}

New-VHD $vhdpath -Dynamic -SizeBytes (16 * 1024 * 1024 * 1024)
$vm = New-VM $vmname -MemoryStartupBytes (2 * 1024 * 1024 *1024)
$vm | Set-VM -ProcessorCount 2
$vm.NetworkAdapters | Connect-VMNetworkAdapter -SwitchName $vmSwitch
$vm | Add-VMHardDiskDrive -ControllerType IDE -Path $vhdpath
$vm | Add-VMDvdDrive -Path $isopath
$vm | Set-VMFloppyDiskDrive -Path $floppyPath

$vm | Start-Vm

while((Get-VM $vmname).State -ne "Off") {
    Start-Sleep 5
}

$ENV:OS_USERNAME="admin"
$ENV:OS_TENANT_NAME="admin"
$ENV:OS_PASSWORD="b3de08ab70e2456c"
$ENV:OS_AUTH_URL="http://192.168.209.130:35357/v2.0/"

$imageName="Windows Server 2012 R2 Std Eval VHD"
$vmName = "vm1"
$keyPath = "C:\Tools\id_rsa_key1"

glance show $imageName | out-null
if (!$lastexitcode) {
    glance image-delete "$IMAGE_NAME"    
}

cmd /c  glance image-create --property hypervisor_type=hyperv --name "$imageName" --container-format bare --disk-format vhd `< $vhdpath
if ($LastExitCode) { throw "glance image-create failed" }

$netId = (neutron net-show net1)[4].Split("|")[2].Trim()
if ($LastExitCode) { throw "neutron net-show failed" }

$out = nova boot  --flavor fl4 --image "$imageName" --key-name key1 --nic net-id=$netId --meta admin_pass=Passw0rd --poll $vmName
if ($LastExitCode) { throw "nova boot failed" }

$vmId = $out[9].Split("|")[2].Trim()
#$vmId = (nova show $vmName)[15].Split("|")[2].Trim()
#if ($LastExitCode) { throw "nova show failed" }

$instanceName = $out[6].Split("|")[2].Trim()
#Get-VMConsole $instanceName

$portId = (neutron port-list --device_id $vmId)[3].Split("|")[1].Trim()
if ($LastExitCode) { throw "neutron port-list failed" }

$floatIpId = (neutron floatingip-list)[3].Split("|")[1].Trim()
if ($LastExitCode) { throw "neutron floatingip-list failed" }

neutron floatingip-associate $floatIpId $portId
if ($LastExitCode) { throw "neutron floatingip-associate failed" }

$floatIp=(neutron floatingip-show $floatIpId)[4].Split("|")[2].Trim()
if ($LastExitCode) { throw "neutron floatingip-show failed" }

Write-Host "IP address: $floatIp"

$password=nova get-password $vmId $keyPath
if ($LastExitCode) { throw "nova get-password failed" }

if(!$password)
{ 
    throw "Password not set in the metadata" 
}

# login via RDP, to be replaced with automated testing via WinRM
# check hostname
#hostname -eq $vmName

pause

#Check partition extension
#diskpart
#list disk
#Output must contain only disk 0

pause

nova delete $vmId
if ($LastExitCode) { throw "nova delete failed" }
