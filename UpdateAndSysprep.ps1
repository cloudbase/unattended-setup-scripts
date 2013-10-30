Param(
  [switch]$InstallCloudbaseInit
)
$ErrorActionPreference = "Stop"

Get-WUInstall -AcceptAll -IgnoreReboot
if (Get-WURebootStatus -Silent)
{
    shutdown /r /t 0
}
else
{
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name Unattend*
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name AutoLogonCount
    if($InstallCloudbaseInit)
    {
        Invoke-WebRequest -Uri http://www.cloudbase.it/downloads/CloudbaseInitSetup_Beta.msi -OutFile C:\Windows\Temp\CloudbaseInitSetup_Beta.msi
        Write-Host "Sleep 60 seconds"
        Start-Sleep -s 60
        Write-Host "Install Cloudbase-Init"
        Start-Process -FilePath msiexec -ArgumentList "/i C:\Windows\Temp\CloudbaseInitSetup.msi /qn /l*v C:\Windows\Temp\CloudbaseInitSetup_Beta.log" -Wait
        Write-Host "Sleep 60 seconds take 2"
        Start-Sleep -s 60
        Write-Host "Install Cloudbase-Init take 2"
        Start-Process -FilePath msiexec -ArgumentList "/i C:\Windows\Temp\CloudbaseInitSetup.msi /qn /l*v C:\Windows\Temp\CloudbaseInitSetup_Beta2.log" -Wait
        C:\Windows\System32\Sysprep\Sysprep.exe /generalize /oobe /shutdown /unattend:C:\Program\ Files\ (x86)\Cloudbase\ Solutions\Cloudbase-Init\conf\Unattend.xml
    }
    else
    {
        C:\Windows\System32\Sysprep\Sysprep.exe /generalize /oobe /shutdown /unattend:C:\Windows\Temp\Unattend.xml
    }
}
