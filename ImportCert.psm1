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

Export-ModuleMember "Import-Certificate"