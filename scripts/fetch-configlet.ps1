$ErrorActionPreference = "Stop"

Function Headers {
    If ($env:GITHUB_TOKEN) { @{ Authorization = "Bearer ${env:GITHUB_TOKEN}" } } Else { @{ } }
}

Function Arch {
    If ([Environment]::Is64BitOperatingSystem) { "64bit" } Else { "32bit" }
}

$headers = Headers
$arch = Arch
$fileName = "configlet-windows-$arch.zip"

$requestOpts = @{
    Headers = $headers
    MaximumRetryCount = 3
    RetryIntervalSec = 1
}

Function Get-DownloadUrl {
    $latestUrl = "https://api.github.com/repos/exercism/configlet-v3/releases/latest"
    Invoke-RestMethod -Uri $latestUrl -PreserveAuthorizationOnRedirect @requestOpts
    | Select-Object -ExpandProperty assets
    | Where-Object { $_.browser_download_url -match $FileName }
    | Select-Object -ExpandProperty browser_download_url
}

$downloadUrl = Get-DownloadUrl
$outputDirectory = "bin"
$outputFile = Join-Path -Path $outputDirectory -ChildPath $fileName
Invoke-WebRequest -Uri $downloadUrl -OutFile $outputFile @requestOpts
Expand-Archive $outputFile -DestinationPath $outputDirectory -Force
Remove-Item -Path $outputFile
