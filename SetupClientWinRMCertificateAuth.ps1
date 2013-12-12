$ErrorActionPreference = "Stop"

# Setup the WinRM client in an elevated command prompt
#& winrm set winrm/config/client `@`{TrustedHosts=`"*`"`}
#& winrm set winrm/config/client/auth `@`{Certificate=`"true`"`}

$remote_host = "192.168.209.134"
$host_cacert_path = "$(pwd)\ca_winrm.pem"
$client_cert_pfx = "$(pwd)\cert.pfx"
$client_cert_pfx_password = "Passw0rd"

# Get the user's personal certificate store
$store = New-Object System.Security.Cryptography.X509Certificates.X509Store(
    [System.Security.Cryptography.X509Certificates.StoreName]::My,
    [System.Security.Cryptography.X509Certificates.StoreLocation]::CurrentUser)
$store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)

# Get the user's Trusted Root CA store
$castore = New-Object System.Security.Cryptography.X509Certificates.X509Store(
    [System.Security.Cryptography.X509Certificates.StoreName]::Root,
    [System.Security.Cryptography.X509Certificates.StoreLocation]::CurrentUser)
$castore.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)

# Import the client cert and its CA cert
$coll = new-object System.Security.Cryptography.X509Certificates.X509Certificate2Collection
$coll.Import($client_cert_pfx, $client_cert_pfx_password,
    ([System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::UserKeySet -bor
     [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::PersistKeySet))

foreach($cert in $coll) {
    # TODO: handle intermediate CAs
    if ($cert.Subject -eq $cert.Issuer) {
        $castore.Add($cert)
    }
    else {
        $store.Add($cert)
        $clientcert = $cert
    }
}

# Import the server's cert CA cert.
# This is necessary only due to a New-PSSession bug as the PSSessionOption.SkipCACheck setting is ignored
$host_cacert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($host_cacert_path)
$castore.Add($host_cacert)

# Open a remote PowerShell session using certificate authentication
$opt = New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck
$session = New-PSSession -ComputerName $remote_host -UseSSL -CertificateThumbprint $clientcert.Thumbprint -SessionOption $opt
Enter-PSSession $session
