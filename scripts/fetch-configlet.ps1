param (
    [Parameter(Mandatory = $false)]
    [Switch]$Confirm
)

$ErrorActionPreference = "Stop"

$scriptUrl = "https://raw.githubusercontent.com/exercism/configlet/main/scripts/fetch-configlet-script.ps1"
$script = Invoke-WebRequest -Uri "${scriptUrl}" -MaximumRetryCount 3 -RetryIntervalSec 1

if ($Confirm.IsPresent) {
    $choice = Read-Host "${script}`n`nDo you want the execute the above script (y/n)?"
    if ("${choice}" -ne "y" -and "${choice}" -ne "Y") {
        exit 0
    }
}

Invoke-Expression "${script}"
