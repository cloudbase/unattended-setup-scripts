$cert_pfx = "cert_self_signed.pfx"
$cert_pfx_password = "Passw0rd"

# Get the machine personal certificate store
$store = New-Object System.Security.Cryptography.X509Certificates.X509Store(
    [System.Security.Cryptography.X509Certificates.StoreName]::My,
    [System.Security.Cryptography.X509Certificates.StoreLocation]::LocalMachine)
$store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)

$cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2(
    $cert_pfx, $cert_pfx_password,
    ([System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::MachineKeySet -bor
     [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::PersistKeySet))
$store.Add($cert)

new-item -path wsman:\localhost\listener -transport https -address * -CertificateThumbPrint $cert.Thumbprint -Force

& winrm set winrm/config/service/auth `@`{Basic=`"true`"`}
if ($LastExitCode) { throw "Failed to setup WinRM basic auth" }

& netsh advfirewall firewall add rule name="WinRM HTTPS" dir=in action=allow protocol=TCP localport=5986
if ($LastExitCode) { throw "Failed to setup WinRM HTTPS firewall rules" }
