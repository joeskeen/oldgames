#!/usr/bin/env pwsh

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('user','system')]
    [string]$InstallScope = 'user'
)

Import-Module "$PSScriptRoot/src/InstallOldGames" -Force

$rootDir = Get-OldGamesRoot
$programsDir = [System.IO.Path]::Join($rootDir, "programs")
if (-not (Test-Path -Path $programsDir)) {
    throw "Programs directory '$programsDir' does not exist."
}

$programs = Get-ChildItem -Path $programsDir -Directory
$programs | ForEach-Object {
    $programDirName = $_.Name
    $fullName = Get-ProgramFullName -ProgramDirName $programDirName
    Write-Host "Installing program '$fullName'..."
    Install-Program -ProgramDirName $programDirName -InstallScope $InstallScope
}
