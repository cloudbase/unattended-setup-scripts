Get-WUInstall -AcceptAll -IgnoreReboot
if (Get-WURebootStatus -Silent)
{ 
    exit 2
}
