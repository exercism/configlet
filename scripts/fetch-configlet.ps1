Function DownloadUrl ([string] $FileName, $Headers) {
    $latestUrl = "https://api.github.com/repos/exercism/configlet-v3/releases/latest"
    $json = Invoke-RestMethod -Headers $Headers -Uri $latestUrl -MaximumRetryCount 3 -RetryIntervalSec 1 -PreserveAuthorizationOnRedirect
    $json.assets | Where-Object { $_.browser_download_url -match $FileName } | Select-Object -ExpandProperty browser_download_url
}

Function Headers {
    If ($GITHUB_TOKEN) { @{ Authorization = "Bearer ${GITHUB_TOKEN}" } } Else { @{ } }
}

Function Arch {
    If ([Environment]::Is64BitOperatingSystem) { "64bit" } Else { "32bit" }
}

$arch = Arch
$headers = Headers
$fileName = "configlet-windows-$arch.zip"
$outputDirectory = "bin"
$outputFile = Join-Path -Path $outputDirectory -ChildPath $fileName
$zipUrl = DownloadUrl -FileName $fileName -Headers $headers

Invoke-WebRequest -Headers $headers -Uri $zipUrl -OutFile $outputFile -MaximumRetryCount 3 -RetryIntervalSec 1 -PreserveAuthorizationOnRedirect
Expand-Archive $outputFile -DestinationPath $outputDirectory -Force
Remove-Item -Path $outputFile
