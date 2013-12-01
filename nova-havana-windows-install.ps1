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

function GitClonePull($path, $url, $branch="master")
{
    Write-Host "Cloning / pulling: $url"

    $needspull = $true

    if (!(Test-Path -path $path))
    {
        git clone -b $branch $url
        if ($LastExitCode) { throw "git clone failed" }
        $needspull = $false
    }

    if ($needspull)
    {
        pushd .
        try
        {
            cd $path

            $branchFound = (git branch)  -match "(.*\s)?$branch"
            if ($LastExitCode) { throw "git branch failed" }

            if($branchFound)
            {
                git checkout $branch
                if ($LastExitCode) { throw "git checkout failed" }
            }
            else
            {
                git checkout -b $branch origin/$branch
                if ($LastExitCode) { throw "git checkout failed" }
            }

            git reset --hard
            if ($LastExitCode) { throw "git reset failed" }

            git clean -f -d
            if ($LastExitCode) { throw "git clean failed" }

            git pull
            if ($LastExitCode) { throw "git pull failed" }
        }
        finally
        {
            popd
        }
    }
}

function PullInstall($path, $url)
{
    GitClonePull $path $url

    pushd .
    try
    {
        cd $path

        python setup.py build --force
        if ($LastExitCode) { throw "python setup.py build failed" }

        python setup.py install --force
        if ($LastExitCode) { throw "python setup.py install failed" }

        # Workaround for a setup related issue
        python setup.py install
        if ($LastExitCode) { throw "python setup.py install failed" }
    }
    finally
    {
        popd
    }
}

function InstallPythonDep($url, $filename) {
    Write-Host "Downloading and installing: $url"
	(new-object System.Net.WebClient).DownloadFile($url, "$pwd\$filename")
	Start-Process -Wait $filename
	del $filename
}

function InstallMSI($url, $filename) {
    Write-Host "Downloading and installing: $url"
	(new-object System.Net.WebClient).DownloadFile($url, "$pwd\$filename")
	Start-Process -Wait msiexec.exe -ArgumentList "/i $filename /qn"
	del $filename
}

InstallMSI "http://www.python.org/ftp/python/2.7.5/python-2.7.5.msi" "python-2.7.5.msi"
$ENV:PATH += ";C:\Python27;C:\Python27\Scripts"

InstallMSI "http://freefr.dl.sourceforge.net/project/sevenzip/7-Zip/9.22/7z922-x64.msi" "7z922-x64.msi"
$ENV:PATH += ";$ENV:ProgramFiles\7-Zip"

$filename = "Git-1.8.4-preview20130916.exe"
$url = "https://msysgit.googlecode.com/files/$filename"
Write-Host "Downloading and installing: $url"
(new-object System.Net.WebClient).DownloadFile($url, "$pwd\$filename")
Start-Process -Wait -FilePath $filename -ArgumentList "/silent" -WindowStyle Hidden
del $filename
$ENV:PATH += ";$ENV:ProgramFiles (x86)\Git\bin\"
# In "%ProgramFiles% (x86)\Git\etc\gitconfig" set "autocrlf = false"

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
if ($LastExitCode) { throw "easy_install failed"}
pip install qpid-python
if ($LastExitCode) { throw "pip install failed"}

PullInstall "pbr" "https://github.com/openstack-dev/pbr.git"
Remove-Item -Recurse -Force "pbr"

PullRelease "nova" "havana" "2013.2"
(new-object System.Net.WebClient).DownloadFile("https://raw.github.com/openstack/nova/efb409019b2a4e711eb09cb1976aa94c90b3d4ba/requirements.txt", "$pwd\dist\nova-2013.2\requirements.txt")
InstallRelease "nova" "2013.2"
Remove-Item -Recurse -Force "dist"
