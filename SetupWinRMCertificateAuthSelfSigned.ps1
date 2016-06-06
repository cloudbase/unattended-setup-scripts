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
$Matches = $clientcert.Extensions[1].Format($false)

# extract the part of the string that we need
$upn = $Matches.Substring(26) #copy from position 26 inclusive to the end

# Map the certificate for the winrm server to know which client connects
New-Item -Path WSMan:\localhost\ClientCertificate -Issuer $clientcert.Thumbprint -Subject $upn -Uri * -Credential $cred -Force
