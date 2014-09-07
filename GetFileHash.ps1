# Get-FileHash has been introduced only in PowerShell 4.0
# Here's a compatible implementation for previous versions (SHA1 only for now)
function Get-FileHash {
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory=$true)]
        [string]$Path,

        [string]$Algorithm = "SHA1"
    )
    process
    {
        if ($Algorithm -ne "SHA1") {
            throw "Unsupported algorithm: $Algorithm"
        }

        $fullPath = Resolve-Path $Path
        $f = [System.IO.File]::OpenRead($fullPath)
        $sham = $null
        try {
            $sham = new-object System.Security.Cryptography.SHA1Managed
            $hash = $sham.ComputeHash($f)

            $hashSB = new-object System.Text.StringBuilder -ArgumentList ($hash.Length * 2)
            foreach ($b in $hash) {
                $sb = $hashSB.AppendFormat("{0:x2}", $b)
            }

            return [pscustomobject]@{Algorithm="SHA1"; Path=$fullPath; Hash=$hashSB.ToString()}
        }
        finally {
            $f.Close()
            if($sham) { $sham.Clear() }
        }
    }
}
