$ErrorActionPreference = "Stop"

$scriptUrl = "https://raw.githubusercontent.com/exercism/configlet/master/scripts/fetch-configlet-script.ps1"
$fetchConfigletScript = Invoke-WebRequest -Uri $scriptUrl -MaximumRetryCount 3 -RetryIntervalSec 1
Invoke-Expression $fetchConfigletScript
