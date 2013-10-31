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
        $Host.UI.RawUI.WindowTitle = "Downloading Cloudbase-Init..."
        Invoke-WebRequest -Uri http://www.cloudbase.it/downloads/CloudbaseInitSetup_Beta.msi -OutFile C:\Windows\Temp\CloudbaseInitSetup_Beta.msi
        
        $Host.UI.RawUI.WindowTitle = "Installing Cloudbase-Init..."
        do 
        {
            $p = Start-Process -Wait -PassThru -FilePath msiexec -ArgumentList "/i C:\Windows\Temp\CloudbaseInitSetup.msi /qn /l*v C:\Windows\Temp\CloudbaseInitSetup_Beta.log"
            if ($p.ExitCode -ne 0)
            {
                Write-Host "Cloudbase-Init setup failed. Retrying after a short break."
                Start-Sleep -s 30
            }
        }
        while($p.ExitCode -ne 0)
        
        $Host.UI.RawUI.WindowTitle = "Running Sysprep..."
        C:\Windows\System32\Sysprep\Sysprep.exe /generalize /oobe /shutdown /unattend:C:\Program\ Files\ (x86)\Cloudbase\ Solutions\Cloudbase-Init\conf\Unattend.xml
    }
    else
    {
        $Host.UI.RawUI.WindowTitle = "Running Sysprep..."      
        C:\Windows\System32\Sysprep\Sysprep.exe /generalize /oobe /shutdown /unattend:C:\Windows\Temp\Unattend.xml
    }
}
