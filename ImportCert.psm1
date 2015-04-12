$ErrorActionPreference = "Stop"

function Import-Certificate()
{
    [CmdletBinding()]
    param (
        [parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [string]$CertificatePath,

        [parameter(Mandatory=$true)]
        [System.Security.Cryptography.X509Certificates.StoreLocation]$StoreLocation,

        [parameter(Mandatory=$true)]
        [System.Security.Cryptography.X509Certificates.StoreName]$StoreName
    )
    PROCESS
    {
        $store = New-Object System.Security.Cryptography.X509Certificates.X509Store(
            $StoreName, $StoreLocation)
        $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)

        $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2(
            $CertificatePath)
        $store.Add($cert)
    }
}

function Import-P12CertificateChain()
{
    [CmdletBinding()]
    param (
        [parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [string]$P12Path,
        # TODO use a SecureString
        [string]$P12Password,
        [switch]$ImportCA
    )
    PROCESS
    {
        $p12AbsPath = Resolve-Path $P12Path

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
        $coll.Import($p12AbsPath, $P12Password,
            ([System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::UserKeySet -bor
             [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::PersistKeySet))

        foreach($cert in $coll) {
            Write-Host $cert.Subject
            Write-Host $cert.Thumbprint

            # TODO: handle intermediate CAs
            if ($cert.Subject -eq $cert.Issuer) {
                if($ImportCA) {
                    $castore.Add($cert)
                }
            }
            else {
                $store.Add($cert)
                $clientcert = $cert
            }
        }
    }
}

Export-ModuleMember "Import-Certificate"
Export-ModuleMember "Import-P12CertificateChain"
