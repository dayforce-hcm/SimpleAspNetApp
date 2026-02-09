$IISExpressPath = Join-Path $env:ProgramFiles "IIS Express\iisexpress.exe"

if (-not (Test-Path $IISExpressPath))
{
    # Try x86 path
    $IISExpressPath = Join-Path ${env:ProgramFiles(x86)} "IIS Express\iisexpress.exe"
    if (-not (Test-Path $IISExpressPath))
    {
        throw "IIS Express not found. Please install IIS Express to run this test."
    }
}

$SourcePath = "$PSScriptRoot\Main"
$PublishPath = "$PSScriptRoot\bin\_PublishedWebsites\Main"
$Url = ((Select-String applicationUrl $SourcePath\Properties\launchSettings.json).Line -split '"')[3]
$Port = [System.Uri]::New($Url).Port
Start-Process powershell -ArgumentList @(
    "-NoProfile",
    "-NoExit",
    "-Command",
    "& '$IISExpressPath' /path:$PublishPath /port:$Port"
)
Start-Sleep -Seconds 1
start $url
