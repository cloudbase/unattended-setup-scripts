$ErrorActionPreference = "Stop"

Import-Module BitsTransfer

$opensslPath = "$ENV:HOMEDRIVE\OpenSSL-Win32"

if($PSVersionTable.PSVersion.Major -lt 4) {
    $scriptPath = split-path -parent $MyInvocation.MyCommand.Definition
    . "$scriptPath\GetFileHash.ps1"
}

function VerifyHash($filename, $expectedHash) {
    $hash = (Get-FileHash -Algorithm SHA1 $filename).Hash
    if ($hash -ne $expectedHash) {
        throw "SHA1 hash not valid for file: $filename. Expected: $expectedHash Current: $hash"
    }
}

function InstallVCRedist2008() {
    $filename = "vcredist_x86_2008.exe"
    $url = "http://download.microsoft.com/download/1/1/1/1116b75a-9ec3-481a-a3c8-1777b5381140/vcredist_x86.exe"
    Start-BitsTransfer -Source $url -Destination $filename

    VerifyHash $filename "56719288ab6514c07ac2088119d8a87056eeb94a"

    Start-Process -Wait -FilePath $filename -ArgumentList "/q"
    del $filename
}

function InstallOpenSSL() {
    if (!(Test-Path $opensslPath)) {
        $filename = "Win32OpenSSL_Light-1_0_1i.exe"
        Start-BitsTransfer -Source "http://slproweb.com/download/$filename" -Destination $filename

        VerifyHash $filename "439BA19F18803432E39F0056209B010A63B96644"

        Start-Process -Wait -FilePath $filename -ArgumentList "/silent /verysilent /sp- /suppressmsgboxes"
        del $filename
    }
}

function GenerateSelfSignedCertificate($certFilePfx, $pfxPassword) {
    $opensslConf = "openssl_server_auth.cnf"

    Set-Content $opensslConf @"
distinguished_name  = req_distinguished_name
[req_distinguished_name]
[v3_req]
[v3_req_server]
extendedKeyUsage = serverAuth
[v3_ca]
"@

    $certFilePem = "server_cert.pem"
    $keyFilePem = "server_cert.key"

    $openssl = "$opensslPath\bin\openssl.exe"
    $subject = "/C=RO/ST=Timis/L=Timisoara/emailAddress=fake@email.com/organizationName=Cloudbase/CN=$ENV:COMPUTERNAME"

    $ENV:OPENSSL_CONF = $opensslConf
    & $openssl req -x509 -nodes -days 3650 -newkey rsa:2048 -out $certFilePem -outform PEM -keyout $keyFilePem -subj $subject -extensions v3_req_server
    if ($LastExitCode) { throw "OpenSSL failed to create the self signed server certificate" }

    & $openssl pkcs12 -export -in $certFilePem -inkey $keyFilePem -out $certFilePfx -password pass:$pfxPassword
    if ($LastExitCode) { throw "OpenSSL failed to export P12 certificate" }

    del $opensslConf
    $ENV:OPENSSL_CONF = ""

    del $certFilePem
    del $keyFilePem
}

function ImportCertificate($certFilePfx, $pfxPassword) {
    # Get the machine personal certificate store
    $store = New-Object System.Security.Cryptography.X509Certificates.X509Store(
        [System.Security.Cryptography.X509Certificates.StoreName]::My,
        [System.Security.Cryptography.X509Certificates.StoreLocation]::LocalMachine)
    $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)

    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2(
        "$(pwd)\$certFilePfx", $pfxPassword,
        ([System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::MachineKeySet -bor
         [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::PersistKeySet))
    $store.Add($cert)

    return $cert.Thumbprint
}

function RemoveExistingWinRMHttpsListener() {
    $httpsListener = Get-Item -Path wsman:\localhost\listener\* | where {$_.Keys | where { $_ -eq "Transport=HTTPS"} }
    if ($httpsListener) {
        Remove-Item -Recurse -Force -Path ("wsman:\localhost\listener\" + $httpsListener.Name)
    }
}

function CreateWinRMHttpsFirewallRule() {
    & netsh advfirewall firewall add rule name="WinRM HTTPS" dir=in action=allow protocol=TCP localport=5986
    if ($LastExitCode) { throw "Failed to setup WinRM HTTPS firewall rules" }
}

$certFilePfx = "server_cert.p12"
$pfxPassword = "Passw0rd"

$osVer = [System.Environment]::OSVersion.Version
if ($osVer.Major -eq 6 -and $osVer.Minor -le 1) {
    InstallVCRedist2008
}

InstallOpenSSL

GenerateSelfSignedCertificate $certFilePfx $pfxPassword

$certThumbprint = ImportCertificate $certFilePfx $pfxPassword

del $certFilePfx

RemoveExistingWinRMHttpsListener

New-Item -Path wsman:\localhost\listener -transport https -address * -CertificateThumbPrint $certThumbprint -Force

Set-Item wsman:\localhost\service\Auth\Basic -Value $true
# Increase the timeout for long running scripts
Set-Item wsman:\localhost\MaxTimeoutms -Value 1800000

CreateWinRMHttpsFirewallRule

#reg key for use by automation to verify this script has completed
if (-not (Test-Path HKLM:\SOFTWARE\cloudbase)) {New-Item -Path HKLM:\SOFTWARE\cloudbase}
Set-ItemProperty -Path HKLM:\SOFTWARE\cloudbase -Name WinRMAccess -Value 1
