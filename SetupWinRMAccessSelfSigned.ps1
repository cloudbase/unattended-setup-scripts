$ErrorActionPreference = "Stop"

$opensslPath = "$ENV:HOMEDRIVE\OpenSSL-Win32"

function VerifyHash($filename, $expectedHash) {
    $hash = (Get-FileHash -Algorithm SHA1 $filename).Hash
    if ($hash -ne $expectedHash) {
        throw "SHA1 hash not valid for file: $filename"
    }
}

function InstallOpenSSL() {
    if (!(Test-Path $opensslPath)) {
        $filename = "Win32OpenSSL_Light-1_0_1f.exe"
        Invoke-WebRequest -Uri "http://slproweb.com/download/$filename" -OutFile $filename

        VerifyHash $filename "B6AD4E63B91A469CAF430CE9CB7FC89FDDAF8D05"

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
    $httpsListener = Get-Item -Path wsman:\localhost\listener\* | where {$_.Keys.Contains("Transport=HTTPS")}
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

InstallOpenSSL

GenerateSelfSignedCertificate $certFilePfx $pfxPassword

$certThumbprint = ImportCertificate $certFilePfx $pfxPassword

del $certFilePfx

RemoveExistingWinRMHttpsListener

New-Item -Path wsman:\localhost\listener -transport https -address * -CertificateThumbPrint $certThumbprint -Force

Set-Item wsman:\localhost\service\Auth\Basic -Value $true

CreateWinRMHttpsFirewallRule
