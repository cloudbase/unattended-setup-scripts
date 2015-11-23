$ErrorActionPreference = "Stop"

# Nano server does not include Invoke-WebRequest
function Invoke-FastWebRequest
{
    [CmdletBinding()]
    Param(
    [Parameter(Mandatory=$True,ValueFromPipeline=$true,Position=0)]
    [System.Uri]$Uri,
    [Parameter(Position=1)]
    [string]$OutFile
    )
    PROCESS
    {
        if(!([System.Management.Automation.PSTypeName]'System.Net.Http.HttpClient').Type)
        {
            $assembly = [System.Reflection.Assembly]::LoadWithPartialName("System.Net.Http")
        }

        [Environment]::CurrentDirectory = (pwd).Path

        if(!$OutFile)
        {
            $OutFile = $Uri.PathAndQuery.Substring($Uri.PathAndQuery.LastIndexOf("/") + 1)
            if(!$OutFile)
            {
                throw "The ""OutFile"" parameter needs to be specified"
            }
        }

        $client = new-object System.Net.Http.HttpClient
        $task = $client.GetAsync($Uri)
        $task.wait()
        $response = $task.Result
        $status = $response.EnsureSuccessStatusCode()

        $outStream = New-Object IO.FileStream $OutFile, Create, Write, None

        try
        {
            $task = $response.Content.ReadAsStreamAsync()
            $task.Wait()
            $inStream = $task.Result

            $contentLength = $response.Content.Headers.ContentLength

            $totRead = 0
            $buffer = New-Object Byte[] 1MB
            while (($read = $inStream.Read($buffer, 0, $buffer.Length)) -gt 0)
            {
                $totRead += $read
                $outStream.Write($buffer, 0, $read);

                if($contentLength)
                {
                    $percComplete = $totRead * 100 / $contentLength
                    Write-Progress -Activity "Downloading: $Uri" -PercentComplete $percComplete
                }
            }
        }
        finally
        {
            $outStream.Close()
        }
    }
}
