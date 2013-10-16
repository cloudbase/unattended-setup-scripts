$filename = "$ENV:TEMP\7z922-x64.msi"
Invoke-WebRequest -uri "http://freefr.dl.sourceforge.net/project/sevenzip/7-Zip/9.22/7z922-x64.msi" -outFile $filename
Start-Process -Wait msiexec.exe -ArgumentList "/i $filename /qn"
del $filename

$modules_dir="C:\Windows\System32\WindowsPowerShell\v1.0\Modules\"

$filename = "$ENV:TEMP\FreeRDP_powershell.zip"
Invoke-WebRequest -uri "https://dl.dropboxusercontent.com/u/9060190/FreeRDP_powershell.zip" -outFile $filename
& "$ENV:ProgramFiles\7-zip\7z.exe" x $filename -o"$modules_dir"
del $filename

move $modules_dir\FreeRDP\libeay32.dll $Env:SystemRoot
move $modules_dir\FreeRDP\ssleay32.dll $Env:SystemRoot
move $modules_dir\FreeRDP\wfreerdp.exe $Env:SystemRoot

Import-Module FreeRDP

