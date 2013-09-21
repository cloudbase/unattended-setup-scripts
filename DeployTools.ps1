$toolsdir = "C:\Tools"
mkdir $toolsdir
cd $toolsdir

$filename = "7z922-x64.msi"
Invoke-WebRequest -uri "http://freefr.dl.sourceforge.net/project/sevenzip/7-Zip/9.22/7z922-x64.msi" -outFile $filename
Start-Process -Wait msiexec.exe -ArgumentList "/i $filename /qn"
del $filename
