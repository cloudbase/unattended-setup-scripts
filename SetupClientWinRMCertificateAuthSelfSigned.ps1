$client_cert_pfx = "$(pwd)\winrm_client_cert.pfx"
$client_cert_pfx_password = "Passw0rd"
$remote_host = "192.168.209.147"

$store = New-Object System.Security.Cryptography.X509Certificates.X509Store(
    [System.Security.Cryptography.X509Certificates.StoreName]::My,
    [System.Security.Cryptography.X509Certificates.StoreLocation]::CurrentUser)
$store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)

$cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2(
    $client_cert_pfx, $client_cert_pfx_password,
    ([System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::MachineKeySet -bor
     [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::PersistKeySet))
$store.Add($cert)

$opt = New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck
$session = New-PSSession -ComputerName $remote_host -UseSSL -CertificateThumbprint $cert.Thumbprint -SessionOption $opt
Enter-PSSession $session
