# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

$ErrorActionPreference = "Stop"
function SetVCVars($version="12.0", $platform="x86_amd64")
{
    if($version -eq "15.0") {
        pushd "$ENV:ProgramFiles (x86)\Microsoft Visual Studio\2017\Community\VC\Auxiliary\Build\"
    } else {
        pushd "$ENV:ProgramFiles (x86)\Microsoft Visual Studio $version\VC\"
    }

    try
    {
        cmd /c "vcvarsall.bat $platform & set" |
        foreach {
          if ($_ -match "=") {
            $v = $_.split("="); set-item -force -path "ENV:\$($v[0])"  -value "$($v[1])"
          }
        }
    }
    finally
    {
        popd
    }
}

function CheckFileHash($path, $hash, $algorithm="SHA1") {
    $h = Get-Filehash -Algorithm $algorithm $path
    if ($h.Hash.ToUpper() -ne $hash.ToUpper()) {
        throw "Hash comparison failed for file: $path"
    }
}

function Expand7z($archive, $outputDir = ".")
{
    pushd .
    try
    {
        cd $outputDir
        &7z.exe x -y $archive
        if ($LastExitCode) { throw "7z.exe failed on archive: $archive"}
    }
    finally
    {
        popd
    }
}

function CheckDir($path)
{
    if (!(Test-Path -path $path))
    {
        mkdir $path
    }
}
function BuildOpenSSL($buildDir, $outputPath, $opensslVersion, $platform, $cmakeGenerator, $platformToolset,
                      $dllBuild=$true, $runTests=$true, $hash=$null)
{
    $opensslBase = "openssl-$opensslVersion"
    $opensslPath = "$ENV:Temp\$opensslBase.tar.gz"
    $opensslUrl = "https://www.openssl.org/source/$opensslBase.tar.gz"

    pushd .
    try
    {
        cd $buildDir

        # Needed by the OpenSSL server
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        (new-object System.Net.WebClient).DownloadFile($opensslUrl, $opensslPath)

        if($hash) { CheckFileHash $opensslPath $hash }

        Expand7z $opensslPath
        del $opensslPath
        Expand7z "$opensslBase.tar"
        del "$opensslBase.tar"

        cd $opensslBase
        &cmake . -G $cmakeGenerator -T $platformToolset

        $platformMap = @{"x86"="VC-WIN32"; "amd64"="VC-WIN64A"; "x86_amd64"="VC-WIN64A"}
        &perl Configure $platformMap[$platform] --prefix="$ENV:OPENSSL_ROOT_DIR"
        if ($LastExitCode) { throw "perl failed" }

        if($platform -eq "amd64" -or $platform -eq "x86_amd64")
        {
            &.\ms\do_win64a
            if ($LastExitCode) { throw "do_win64 failed" }
        }
        elseif($platform -eq "x86")
        {
            &.\ms\do_nasm
            if ($LastExitCode) { throw "do_nasm failed" }
        }
        else
        {
            throw "Invalid platform: $platform"
        }

        if($dllBuild)
        {
            $makFile = "ms\ntdll.mak"
        }
        else
        {
            $makFile = "ms\nt.mak"
        }

        &nmake -f $makFile
        if ($LastExitCode) { throw "nmake failed" }

        if($runTests)
        {
            &nmake -f $makFile test
            if ($LastExitCode) { throw "nmake test failed" }
        }

        &nmake -f $makFile install
        if ($LastExitCode) { throw "nmake install failed" }

        copy "$ENV:OPENSSL_ROOT_DIR\bin\*.dll" $outputPath
        copy "$ENV:OPENSSL_ROOT_DIR\bin\*.exe" $outputPath
    }
    finally
    {
        popd
    }
}

# Build tools

# Visual Studio 2017 Community edition or above (tested also with 2013 and 2105, change the following variables accordingly in case)
# CMake: https://cmake.org/files/v3.10/cmake-3.10.0-rc4-win64-x64.msi
# ActivePerl: http://downloads.activestate.com/ActivePerl/releases/5.24.2.2403/ActivePerl-5.24.2.2403-MSWin32-x64-403863.exe
# NASM: http://www.nasm.us/pub/nasm/releasebuilds/2.13/win64/nasm-2.13-installer-x64.exe
# 7-zip: http://www.7-zip.org/a/7z1604-x64.exe

# Make sure ActivePerl comes before MSYS Perl, otherwise
# the OpenSSL build will fail
$ENV:PATH = "C:\Perl64\bin;$ENV:PATH"
$ENV:PATH += ";$ENV:ProgramFiles\7-Zip"
$ENV:PATH += ";$ENV:ProgramFiles\CMake\bin"
$ENV:PATH += ";$ENV:ProgramFiles\nasm"

# Visual Studio 2017, amd64 build, change as needed
$vsVersion = "15.0"
$vsPlatform = "amd64"
$cmakeGenerator = "Visual Studio 15 2017 Win64"
$platformToolset = "v150"

# Change OpenSSL version and hash based on your requirements, e.g.: 1.1.0g
$opensslVersion = "1.0.2m"
$opensslSha1 = "27fb00641260f97eaa587eb2b80fab3647f6013b"

# Set to false for a static build
$dllBuild = $true
# Set to false to skip the tests
$runTests = $true

# Change the  build and output path as needed
$buildDir = "C:\Build\"
$outputPath = "$buildDir\bin"

CheckDir $buildDir
CheckDir $outputPath
$ENV:OPENSSL_ROOT_DIR="$outputPath\OpenSSL"

SetVCVars $vsVersion $vsPlatform
BuildOpenSSL $buildDir $outputPath $opensslVersion $vsPlatform $cmakeGenerator $platformToolset $dllBuild $runTests $opensslSha1

Write-Output "Done! The generated OpenSSL binaries are available in: $outputPath"

