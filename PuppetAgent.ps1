#ps1_sysnative

$ErrorActionPreference = "Stop"

$puppet_master_server_ip = "192.168.209.135"
$puppet_master_server_name = "puppet"

# For Puppet Enterprise replace the following url with:
# "https://pm.puppetlabs.com/cgi-bin/download.cgi?ver=latest&dist=win"
$puppet_agent_msi_url = "https://downloads.puppetlabs.com/windows/puppet-3.4.3.msi"

if ($puppet_master_server_ip) {
    # Validate IP address
    $ip = [System.Net.IPAddress]::Parse($puppet_master_server_ip)
    # Add to hosts file
    Add-Content -Path $ENV:SystemRoot\System32\Drivers\etc\hosts -Value "$puppet_master_server_ip $puppet_master_server_name"
}

$puppet_agent_msi_path = Join-Path $ENV:TEMP puppet_agent.msi

# You can also use Invoke-WebRequest but this is way faster :)
Import-Module BitsTransfer
Start-BitsTransfer -Source $puppet_agent_msi_url -Destination $puppet_agent_msi_path

cmd /c start /wait msiexec /qn /i $puppet_agent_msi_path /l*v puppet_agent_msi_log.txt PUPPET_MASTER_SERVER=$puppet_master_server_name
if ($lastexitcode) {
    throw "Puppet agent setup failed"
}

del $puppet_agent_msi_path
