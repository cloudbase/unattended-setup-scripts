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

        [System.Flags]
        public enum PortType
        {
            Host = 1,
            External = 2
        }
    }
"@

function GetSwitchEthernetPortAllocationSettingData($vswitchName, $portType) {
    $eps = @()
    if($portType -band [cloudbase.PortType]::External) {
        $eps += gwmi -Namespace $ns -Class Msvm_ExternalEthernetPort
    }
    if($portType -band [cloudbase.PortType]::Host) {
        $eps += gwmi -Namespace $ns -Class Msvm_InternalEthernetPort
    }

    foreach($ep in $eps) {
        $lep1 = gwmi -Namespace $ns -Query "ASSOCIATORS OF {$ep} WHERE ResultClass=Msvm_LANEndpoint AssocClass=Msvm_EthernetDeviceSAPImplementation"
        if($lep1) {
            $lep2 = gwmi -Namespace $ns -Query "ASSOCIATORS OF {$lep1} WHERE ResultClass=Msvm_LANEndpoint AssocClass=Msvm_ActiveConnection"
            $eswp = gwmi -Namespace $ns -Query "ASSOCIATORS OF {$lep2} WHERE ResultClass=Msvm_EthernetSwitchPort AssocClass=Msvm_EthernetDeviceSAPImplementation"
            $sw = gwmi -Namespace $ns -Query "ASSOCIATORS OF {$eswp} WHERE ResultClass=Msvm_VirtualEthernetSwitch"
            if($sw.ElementName -eq $vswitchName) {
                gwmi -Namespace $ns -Query "ASSOCIATORS OF {$eswp} WHERE ResultClass=Msvm_EthernetPortAllocationSettingData AssocClass=Msvm_ElementSettingData"
            }
        }
    }
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
                } else {
                    Start-Sleep -Milliseconds 200
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
        $portTypes = @([cloudbase.PortType]::External, [cloudbase.PortType]::Host)

        foreach($portType in $portTypes) {
            $epasds = GetSwitchEthernetPortAllocationSettingData $SwitchName $portType
            foreach($epasd in $epasds) {
                $monitorModeInfo = New-Object -TypeName PSObject
                Add-Member -InputObject $monitorModeInfo -MemberType NoteProperty -Name "PortType" -Value $portType

                $espssd = GetEthernetSwitchPortSecuritySettingData $epasd
                if ($espssd) {
                    $mode = [cloudbase.PortMonitorMode]$espssd.MonitorMode
                } else {
                    $mode = [cloudbase.PortMonitorMode]::None
                }

                Add-Member -InputObject $monitorModeInfo -MemberType NoteProperty -Name "MonitorMode" -Value $mode
                $monitorModeInfo
            }
        }
    }
}

function Set-VMSwitchPortMonitorMode() {
     param(
        [Parameter(ValueFromPipeline=$true, Position=0, Mandatory=$true)] [string] $SwitchName,
        [Parameter(Position=1, Mandatory=$true)] [cloudbase.PortMonitorMode] $MonitorMode,
        [Parameter(Position=2)] [cloudbase.PortType] $PortType = [cloudbase.PortType]::External -bor [cloudbase.PortType]::Host
    )

    process {
        $epasds = GetSwitchEthernetPortAllocationSettingData $SwitchName $PortType
        if(!$epasds) {
            throw "Port for VMSwitch named ""$SwitchName"" not found"
        } else {
            foreach($epasd in $epasds) {
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
    }
}

Export-ModuleMember Get-VMSwitchPortMonitorMode
Export-ModuleMember Set-VMSwitchPortMonitorMode
