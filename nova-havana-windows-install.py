# Totally unsupported script to quickly install Nova on Windows
# Get ready for some clicks on "Next,Next,Next"...
#
# Note: start from an elevated Powershell

$ErrorActionPreference = "Stop"

function Expand7z($archive)
{
	&7z.exe x -y $archive
	if ($LastExitCode) { throw "7z.exe failed on archive: $archive"}
}

function CheckRemoveDir($path)
{
	if (Test-Path $path) {
		Remove-Item -Recurse -Force $path
	}
}

function PullRelease($project, $release, $version)
{
	pushd .
    try
    {
        $projectVer = "$project-$version"
        $tarFile = "$projectVer.tar"
        $tgzFile = "$tarFile.gz"
        $url = "https://launchpad.net/$project/$release/$version/+download/$tgzFile"

        Write-Host "Downloading: $url"

		(new-object System.Net.WebClient).DownloadFile($url, (join-path $pwd $tgzFile))

        Expand7z $tgzFile
        Remove-Item -Force $tgzFile
        cd ".\dist"
        CheckRemoveDir $projectVer
        Expand7z $tarFile
        Remove-Item -Force $tarFile
    }
    finally
    {
        popd
    }
}

function InstallRelease($project, $version)
{
	pushd .
    try
    {
        $projectVer = "$project-$version"
        cd ".\dist"
        cd $projectVer
        &python setup.py install --force
        if ($LastExitCode) { throw "python setup.py build failed" }
        cd ..
        Remove-Item -Recurse -Force $projectVer
    }
    finally
    {
        popd
    }
}

function PullInstallRelease($project, $release, $version)
{
    PullRelease $project $release $version
    InstallRelease $project $version
}

function InstallPythonDep($url, $filename) {
	(new-object System.Net.WebClient).DownloadFile($url, "$pwd\$filename")
	Start-Process -Wait $filename
	del $filename
}

function InstallMSI($url, $filename) {
	(new-object System.Net.WebClient).DownloadFile($url, "$pwd\$filename")
	Start-Process -Wait msiexec.exe -ArgumentList "/i $filename /qn"
	del $filename
}

InstallMSI "http://www.python.org/ftp/python/2.7.5/python-2.7.5.msi" "python-2.7.5.msi"
$ENV:PATH += ";C:\Python27;C:\Python27\Scripts"

InstallMSI "http://freefr.dl.sourceforge.net/project/sevenzip/7-Zip/9.22/7z922-x64.msi" "7z922-x64.msi"
$ENV:PATH += ";$ENV:ProgramFiles\7-Zip"

#$filename = "Win32OpenSSL_Light-1_0_1e.exe"
#(new-object System.Net.WebClient).DownloadFile("http://slproweb.com/download/$filename", "$pwd\$filename")
#Start-Process -Wait -FilePath $filename -ArgumentList "/silent /verysilent /sp- /suppressmsgboxes"
#del $filename
#$ENV:PATH += ";C:\OpenSSL-Win32\Bin"

InstallPythonDep "https://pypi.python.org/packages/2.7/s/setuptools/setuptools-0.6c11.win32-py2.7.exe#md5=57e1e64f6b7c7f1d2eddfc9746bbaf20" "setuptools-0.6c11.win32-py2.7.exe"
InstallPythonDep "https://pypi.python.org/packages/2.7/p/pyOpenSSL/pyOpenSSL-0.13.1.win32-py2.7.exe#md5=02b016ed32fffcff56568e5834edcae6" "pyOpenSSL-0.13.1.win32-py2.7.exe"
InstallPythonDep "https://pypi.python.org/packages/2.7/g/greenlet/greenlet-0.4.1.win32-py2.7.exe#md5=8f12784e041be3d795fb2d6771b3af76" "greenlet-0.4.1.win32-py2.7.exe"
InstallPythonDep "https://pypi.python.org/packages/2.7/l/lxml/lxml-3.2.4.win32-py2.7.exe#md5=bf69543928b7f5f638d30b8eddedda09" "lxml-3.2.4.win32-py2.7.exe"
InstallPythonDep "https://pypi.python.org/packages/2.7/p/psutil/psutil-1.2.1.win32-py2.7.exe#md5=c4264532a64414cf3aa0d8b17d17e015" "psutil-1.2.1.win32-py2.7.exe"
# The following packages come from untrusted sources, to be recompiled for production usage
InstallPythonDep "http://downloads.sourceforge.net/project/pywin32/pywin32/Build%20218/pywin32-218.win32-py2.7.exe?r=http%3A%2F%2Fsourceforge.net%2Fprojects%2Fpywin32%2Ffiles%2Fpywin32%2FBuild%2520218%2F&ts=1385677770&use_mirror=dfn" "pywin32-218.win32-py2.7.exe"
InstallPythonDep "http://downloads.sourceforge.net/project/numpy/NumPy/1.8.0/numpy-1.8.0-win32-superpack-python2.7.exe?r=http%3A%2F%2Fsourceforge.net%2Fprojects%2Fnumpy%2Ffiles%2FNumPy%2F1.8.0%2F&ts=1385583346&use_mirror=netcologne" "numpy-1.8.0-win32-superpack-python2.7.exe"
InstallPythonDep "http://www.voidspace.org.uk/downloads/pycrypto26/pycrypto-2.6.win32-py2.7.exe" "pycrypto-2.6.win32-py2.7.exe"

easy_install.exe pip
pip install pbr==0.5.22
pip install qpid-python

PullRelease "nova" "havana" "2013.2"

#Note: there's a conflit with the version of "six" in use. You'll see an error if you try to start nova-compute

notepad++ dist\nova-2013.2\requirements.txt

Replace the line "six<1.40" with "six"

pip install -U six
InstallRelease "nova" "2013.2"



