& "$ENV:ProgramFiles\7-Zip\7z.exe" x jre-7u55-windows-x64.tar.gz
& "$ENV:ProgramFiles\7-Zip\7z.exe" x -oC:\ jre-7u55-windows-x64.tar
del jre-7u51-windows-x64.tar

$javaHome = "c:\jre1.7.0_55"
$jenkinsBaseUrl="http://10.0.0.10:8080"
$username = "Administrator"
$password = "Passw0rd"

echo "deployment.security.level=MEDIUM" > "$javaHome\lib\deployment.properties"

Install-WindowsFeature NET-Framework-Core
#dism.exe /online /enable-feature /featurename:netfx3 /all /source:d:\sources\sxs
#reboot?

$slaveSecret = "547260c564f5b933b905b45afbab5e9daef9cdab9abb02a76aebfae31249c46b"


$slaveHostName = [System.Net.Dns]::GetHostName()

# Download jnlp file by open web browser at:
"http://10.73.76.93:8080/computer/$slaveHostName/slave-agent.jnlp"

&"$javaHome\bin\javaws.exe" slave-agent.jnlp

mkdir c:\Jenkins
#Right click install as service

. .\lsawrapper.ps1

$serviceName = "jenkinsslave-C__Jenkins"

&sc.exe stop $serviceName
&sc.exe config $serviceName obj= ".\$username" password= $password

. .\lsawrapper.ps1
[LsaWrapper.LsaWrapperCaller]::AddPrivileges($username, "SeServiceLogonRight")
&sc.exe start $serviceName




#$serviceDisplayName = "Jenkins Slave"
#$secpasswd = ConvertTo-SecureString $password -AsPlainText -Force
#$c = New-Object System.Management.Automation.PSCredential (".\$username", $secpasswd)
#New-Service -Name $serviceName -DisplayName $serviceDisplayName -BinaryPathName "C:\Jenkins\jenkins-slave.exe" -StartupType Automatic -Credential $c



