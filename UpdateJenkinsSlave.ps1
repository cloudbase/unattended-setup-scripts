# Schedule with:
# schtasks.exe /create /tn Jenkins-Slave-Update /tr "powershell -NonInteractive -File c:\Tools\UpdateJenkinsSlave.ps1" /sc DAILY /ru Administrator /rp /st 01:00:00

$ErrorActionPreference = "Stop"

$jenkinsBaseUrl = "http://10.73.76.93:8080"
$jenkinsSlaveDir = "c:\Jenkins"

$tmpFile = "$jenkinsSlaveDir\slave.jar.tmp"
$slaveJar = "$jenkinsSlaveDir\slave.jar"

Invoke-WebRequest -Uri "$jenkinsBaseUrl/jnlpJars/slave.jar" -OutFile $tmpFile

$tmpFileHash = (Get-FileHash $tmpFile).Hash
$oldFileHash = (Get-FileHash $slaveJar).Hash

if ($tmpFileHash -ne $oldFileHash) {
    echo "Updating $slaveJar"
    net stop 'Jenkins Slave'
    get-process | where {$_.Name -eq 'java'} | kill
    del $slaveJar
    move $tmpFile $slaveJar
    net start 'Jenkins Slave'
}
else {
    echo "No need to update"
    del $tmpFile
}

