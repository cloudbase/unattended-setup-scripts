Param(
  [switch]$InstallCloudbaseInit
)
$ErrorActionPreference = "Stop"

$Host.UI.RawUI.WindowTitle = "Installing updates..."

Get-WUInstall -AcceptAll -IgnoreReboot
if (Get-WURebootStatus -Silent)
{
    $Host.UI.RawUI.WindowTitle = "Updates installation finished. Rebooting."
    shutdown /r /t 0
}
else
{
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name Unattend*
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name AutoLogonCount
    if($InstallCloudbaseInit)
    {
        Invoke-WebRequest -Uri https://dl.dropboxusercontent.com/u/9060190/InstallCloudbaseInit.ps1 -OutFile C:\Windows\Temp\InstallCloudbaseInit.ps1
        C:\Windows\Temp\InstallCloudbaseInit.ps1

        #$Host.UI.RawUI.WindowTitle = "Running Sysprep..."
        #C:\Windows\System32\Sysprep\Sysprep.exe /generalize /oobe /shutdown /unattend:"C:\Program\ Files\ (x86)\Cloudbase\ Solutions\Cloudbase-Init\conf\Unattend.xml"
    }
    else
    {
        $Host.UI.RawUI.WindowTitle = "Running Sysprep..."      
        C:\Windows\System32\Sysprep\Sysprep.exe /generalize /oobe /shutdown /unattend:C:\Windows\Temp\Unattend.xml
    }
}
