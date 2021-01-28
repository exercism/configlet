<#
.SYNOPSIS
    Fetch the latest version of configlet.
.DESCRIPTION
    Fetch the latest version of configlet. Once completed, the bin/ directory
    will contain the configlet.exe binary.
.PARAMETER Confirm
    Require a confirmation from the user before fetching the configlet binary.
.EXAMPLE
    The example below will fetch the latest version of configlet:
    PS C:\> ./bin/fetch-configlet.ps1

    The example below will fetch the latest version of configlet, but only
    if the user explicitly gives permission to do so:
    PS C:\> ./bin/fetch-configlet.ps1 -Confirm
.NOTES
    The script should be run from the track's root directory.
#>

param (
    [Parameter(Mandatory = $false)]
    [Switch]$Confirm
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Download the script that will fetch the configlet.exe binary
$scriptUrl = "https://raw.githubusercontent.com/exercism/configlet/main/scripts/fetch-configlet-script.ps1"
$script = Invoke-WebRequest -Uri "${scriptUrl}" -MaximumRetryCount 3 -RetryIntervalSec 1

# Require confirmation from the user before executing the fetch script
# if the -Confirm switch argument was passed
if ($Confirm.IsPresent) {
    $choice = Read-Host "${script}`n`nDo you want the execute the above script (y/n)?"
    if ("${choice}" -ne "y" -and "${choice}" -ne "Y") {
        exit 0
    }
}

# Execute the fetch script
Invoke-Expression "${script}"
