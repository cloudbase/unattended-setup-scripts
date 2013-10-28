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
    msiexec /i C:\Windows\Temp\CloudbaseInitSetup.msi /qn /l*v C:\Windows\Temp\CloudbaseInitSetup_Beta.log
    C:\Windows\System32\Sysprep\Sysprep.exe /generalize /oobe /shutdown /unattend:C:\Windows\Temp\Unattend.xml
}
