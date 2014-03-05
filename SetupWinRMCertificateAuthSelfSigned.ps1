$ErrorActionPreference = "Stop"

$username = "Administrator"
$password = "Passw0rd"

$client_cert_path = "$(pwd)\cert.pem"

# Enable certificate authentication
& winrm set winrm/config/service/auth `@`{Certificate=`"true`"`}

# Import the client cert as a CA cert
$clientcert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($client_cert_path)
$castore = New-Object System.Security.Cryptography.X509Certificates.X509Store(
    [System.Security.Cryptography.X509Certificates.StoreName]::Root,
    [System.Security.Cryptography.X509Certificates.StoreLocation]::LocalMachine)
$castore.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
$castore.Add($clientcert)

$secure_password = ConvertTo-SecureString $password -AsPlainText -Force
# For domain auth just replace $ENV:COMPUTERNAME with the domain name
$cred = New-Object System.Management.Automation.PSCredential "$ENV:COMPUTERNAME\$username", $secure_password

# Get the UPN from the cert extension
$clientcert.Extensions[1].Format($false) -match ".*=(.*)"
$upn = $Matches[1]

New-Item -Path WSMan:\localhost\ClientCertificate -Issuer $clientcert.Thumbprint -Subject $upn -Uri * -Credential $cred -Force
