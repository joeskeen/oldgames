[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-zA-Z0-9_\.\-]+@[a-zA-Z0-9_\.\-]+$')]
    [string]$UserRemoteHost
)

rsync -au $PSScriptRoot/envs ${UserRemoteHost}:/opt/oldgames/
rsync -au $PSScriptRoot/programs ${UserRemoteHost}:/opt/oldgames/
rsync -au $PSScriptRoot/src ${UserRemoteHost}:/opt/oldgames/
rsync -au $PSScriptRoot/utils ${UserRemoteHost}:/opt/oldgames/
Get-ChildItem $PSScriptRoot -Filter '*.ps1' | ForEach-Object {
    rsync -au $_ ${UserRemoteHost}:/opt/oldgames/
}
