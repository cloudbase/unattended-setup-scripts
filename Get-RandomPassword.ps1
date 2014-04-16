<#
Copyright 2014 Cloudbase Solutions Srl

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
#>

$Source = @"
using System;
using System.Text;
using System.Runtime.InteropServices;

namespace PSCloudbase
{
    public sealed class Win32CryptApi
    {
        public static long CRYPT_SILENT                     = 0x00000040;
        public static long CRYPT_VERIFYCONTEXT              = 0xF0000000;
        public static int PROV_RSA_FULL                     = 1;

        [DllImport("advapi32.dll", CharSet=CharSet.Auto, SetLastError=true)]
        [return : MarshalAs(UnmanagedType.Bool)]
        public static extern bool CryptAcquireContext(ref IntPtr hProv,
                                                      StringBuilder pszContainer, // Don't use string, as Powershell replaces $null with an empty string
                                                      StringBuilder pszProvider, // Don't use string, as Powershell replaces $null with an empty string
                                                      uint dwProvType,
                                                      uint dwFlags);

        [DllImport("Advapi32.dll", EntryPoint = "CryptReleaseContext", CharSet = CharSet.Unicode, SetLastError = true)]
        public static extern bool CryptReleaseContext(IntPtr hProv, Int32 dwFlags);

        [DllImport("advapi32.dll", SetLastError=true)]
        public static extern bool CryptGenRandom(IntPtr hProv, uint dwLen, byte[] pbBuffer);

        [DllImport("Kernel32.dll")]
        public static extern uint GetLastError();
    }
}
"@

Add-Type -TypeDefinition $Source -Language CSharp

function Get-RandomPassword
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory=$true)]
        [int]$Length
    )
    process
    {
        $hProvider = 0
        try
        {
            if(![PSCloudbase.Win32CryptApi]::CryptAcquireContext([ref]$hProvider, $null, $null,
                                                                 [PSCloudbase.Win32CryptApi]::PROV_RSA_FULL,
                                                                 ([PSCloudbase.Win32CryptApi]::CRYPT_VERIFYCONTEXT -bor
                                                                  [PSCloudbase.Win32CryptApi]::CRYPT_SILENT)))
            {
                throw "CryptAcquireContext failed with error: 0x" + "{0:X0}" -f [PSCloudbase.Win32CryptApi]::GetLastError()
            }

            $buffer = New-Object byte[] $Length
            if(![PSCloudbase.Win32CryptApi]::CryptGenRandom($hProvider, $Length, $buffer))
            {
                throw "CryptGenRandom failed with error: 0x" + "{0:X0}" -f [PSCloudbase.Win32CryptApi]::GetLastError()
            }

            $buffer | ForEach-Object { $password += "{0:X0}" -f $_ }
            return ConvertTo-SecureString -AsPlainText $password -Force
        }
        finally
        {
            if($hProvider)
            {
                $retVal = [PSCloudbase.Win32CryptApi]::CryptReleaseContext($hProvider, 0)
            }
        }
    }
}
