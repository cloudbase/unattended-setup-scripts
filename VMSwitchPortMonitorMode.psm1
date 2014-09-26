# Copyright 2014 Cloudbase Solutions Srl
#
#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.

$ns = "root\virtualization\v2"

Add-Type -TypeDefinition @"
    namespace cloudbase
    {
        public enum PortMonitorMode
        {
            None,
            Destination,
            Source
        }
    }
"@

function GetSwitchEthernetPortAllocationSettingData($vswitchName) {
    $eps = @()
    $eps += gwmi -Namespace $ns -Class Msvm_ExternalEthernetPort
    $eps += gwmi -Namespace $ns -Class Msvm_InternalEthernetPort
    foreach($ep in $eps) {
        $lep1 = gwmi -Namespace $ns -Query "ASSOCIATORS OF {$ep} WHERE ResultClass=Msvm_LANEndpoint AssocClass=Msvm_EthernetDeviceSAPImplementation"
        if($lep1) {
            $lep2 = gwmi -Namespace $ns -Query "ASSOCIATORS OF {$lep1} WHERE ResultClass=Msvm_LANEndpoint AssocClass=Msvm_ActiveConnection"
            $eswp = gwmi -Namespace $ns -Query "ASSOCIATORS OF {$lep2} WHERE ResultClass=Msvm_EthernetSwitchPort AssocClass=Msvm_EthernetDeviceSAPImplementation"
            $sw = gwmi -Namespace $ns -Query "ASSOCIATORS OF {$eswp} WHERE ResultClass=Msvm_VirtualEthernetSwitch"
            if($sw.ElementName -eq $vswitchName) {
                return gwmi -Namespace $ns -Query "ASSOCIATORS OF {$eswp} WHERE ResultClass=Msvm_EthernetPortAllocationSettingData AssocClass=Msvm_ElementSettingData"
            }
        }
    }

    throw "No internal or external VMSwitch named ""$vswitchName"" was found"
}

function CheckJob($out) {
    if($out.ReturnValue -ne 0) {
        if($out.ReturnValue -ne 4096) {
            throw "Job failed with status: ${$out.ReturnValue}"
        } else {
            do {
                $job = [wmi]$out.Job
                if ($job.JobState -ne 4096) {
                    if ($job.JobState -eq 7) {
                        return
                    } else {
                        throw $job.ErrorDescription
                    }
                }
            } while ($true)
        }
    }
}

function GetEthernetSwitchPortSecuritySettingData($epasd) {
    return gwmi -Namespace $ns -Query "ASSOCIATORS OF {$epasd} WHERE ResultClass=Msvm_EthernetSwitchPortSecuritySettingData AssocClass=Msvm_EthernetPortSettingDataComponent"
}

function Get-VMSwitchPortMonitorMode() {
     param(
        [Parameter(ValueFromPipeline=$true, Position=0, Mandatory=$true)] [string] $SwitchName
    )

    process {
        $epasd = GetSwitchEthernetPortAllocationSettingData $SwitchName
        $espssd = GetEthernetSwitchPortSecuritySettingData $epasd
        if ($espssd) {
            [cloudbase.PortMonitorMode]$espssd.MonitorMode
        } else {
            [cloudbase.PortMonitorMode]::None
        }
    }
}

function Set-VMSwitchPortMonitorMode() {
     param(
        [Parameter(ValueFromPipeline=$true, Position=0, Mandatory=$true)] [string] $SwitchName,
        [Parameter(Position=1, Mandatory=$true)] [cloudbase.PortMonitorMode] $MonitorMode
    )

    process {
        $epasd = GetSwitchEthernetPortAllocationSettingData $SwitchName
        $espssd = GetEthernetSwitchPortSecuritySettingData $epasd

        if ($espssd) {
            if($espssd.MonitorMode -ne [int]$MonitorMode) {
                $espssd.MonitorMode = [int]$MonitorMode
                $svc = gwmi -Namespace $ns -Class Msvm_VirtualEthernetSwitchManagementService
                CheckJob $svc.ModifyFeatureSettings(@($espssd.GetText(1)))
            }
        } else {
            if($MonitorMode -ne [int][cloudbase.PortMonitorMode]::None) {
                $espssd = gwmi -Namespace $ns -Class Msvm_EthernetSwitchPortSecuritySettingData | where { $_.InstanceId.EndsWith("\Default") }
                $espssd.MonitorMode = [int]$MonitorMode
                $svc = gwmi -Namespace $ns -Class Msvm_VirtualEthernetSwitchManagementService
                CheckJob $svc.AddFeatureSettings($epasd, @($espssd.GetText(1)))
            }
        }
    }
}

Export-ModuleMember Get-VMSwitchPortMonitorMode
Export-ModuleMember Set-VMSwitchPortMonitorMode
