$toolsdir = "C:\Tools"
mkdir $toolsdir
cd $toolsdir

$filename = "7z922-x64.msi"
Invoke-WebRequest -uri "http://freefr.dl.sourceforge.net/project/sevenzip/7-Zip/9.22/7z922-x64.msi" -outFile $filename
Start-Process -Wait msiexec.exe -ArgumentList "/i $filename /qn"
del $filename

$filename = "npp.6.4.5.Installer.exe"
Invoke-WebRequest -uri "http://download.tuxfamily.org/notepadplus/6.4.5/npp.6.4.5.Installer.exe" -outFile $filename
Start-Process -Wait -FilePath $filename -ArgumentList "/S"
del $filename
setx /m PATH "$ENV:PATH;$ENV:ProgramFiles (x86)\Notepad++"

Invoke-WebRequest -uri "https://dl.dropboxusercontent.com/u/9060190/wget.exe" -OutFile "wget.exe"
Invoke-WebRequest -uri  "http://the.earth.li/~sgtatham/putty/latest/x86/putty.exe" -OutFile "putty.exe"
Invoke-WebRequest -uri  "http://the.earth.li/~sgtatham/putty/latest/x86/pscp.exe" -OutFile "pscp.exe"

$modules_dir = "$ENV:USERPROFILE\Documents\WindowsPowerShell\Modules"
mkdir $modules_dir

$filename = "PSWindowsUpdate.zip"
Invoke-WebRequest -Uri "http://gallery.technet.microsoft.com/scriptcenter/2d191bcd-3308-4edd-9de2-88dff796b0bc/file/41459/25/PSWindowsUpdate.zip" -OutFile $filename
cmd /c "C:\Program Files\7-Zip\7z.exe" x -o%USERPROFILE%\Documents\WindowsPowerShell\Modules $filename
del $filename

Invoke-WebRequest -Uri "https://raw.github.com/cloudbase/unattended-setup-scripts/master/GetWindowsUpdates.ps1" -OutFile "GetWindowsUpdates.ps1"

Invoke-WebRequest -uri "https://raw.github.com/cloudbase/unattended-setup-scripts/master/Unattend.xml" -OutFile "Unattend.xml"
mkdir C:\Windows\Setup\Scripts
Invoke-WebRequest -uri "https://github.com/cloudbase/unattended-setup-scripts/raw/master/SetupComplete.cmd" -OutFile "C:\Windows\Setup\Scripts\SetupComplete.cmd"
