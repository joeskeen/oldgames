#!/usr/bin/env pwsh

<#
.SYNOPSIS
Copies existing per-user savedata to the configured user data root and repairs
the parent path stored inside each differencing VHD.

.DESCRIPTION
Differencing VHDs record the absolute and relative paths of their parent
image. Simply copying a savedata VHD to a new location leaves those paths
pointing at the old location, so the child no longer mounts. This script
copies the savedata and rewrites both parent locators to the game image in
the current programs directory.

The source tree is never modified or deleted. Machine-local files (desktop
entries) are skipped, and transient per-run files are not copied.

.PARAMETER From
Existing user data directory. Defaults to ~/.config/oldgames.

.PARAMETER To
Destination user data root. Defaults to the value from Get-OldGamesConfig
(/etc/oldgames/config.json, the per-user config, or OLDGAMES_USER_DATA_ROOT).

.PARAMETER ProgramsRoot
Directory containing the game install images (the VHD parents). Defaults to
<repository>/programs. Pass the NAS programs path when the scripts run from a
different checkout than the programs.

.PARAMETER Force
Overwrite files that already exist in the destination.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter()]
    [string]$From = [System.IO.Path]::Join($HOME, '.config', 'oldgames'),

    [Parameter()]
    [string]$To,

    [Parameter()]
    [string]$ProgramsRoot,

    [Parameter()]
    [switch]$Force
)

Import-Module "$PSScriptRoot/src/InstallOldGames" -Force

$ErrorActionPreference = 'Stop'

if (-not $To) {
    $To = (Get-OldGamesConfig).UserDataRoot
}
if (-not $ProgramsRoot) {
    $ProgramsRoot = [System.IO.Path]::Join((Get-OldGamesRoot), 'programs')
}

if (-not (Test-Path -LiteralPath $From -PathType Container)) {
    throw "Source user data directory '$From' does not exist."
}
$fromPath = (Resolve-Path -LiteralPath $From).Path

# Do not silently create a NAS path when the NAS is not mounted. The parent
# of the configured data root must already exist (for example
# /mnt/nas/games/users/alice).
$toParent = Split-Path -Parent $To
if (-not (Test-Path -LiteralPath $toParent -PathType Container)) {
    throw "The destination parent '$toParent' does not exist. If this is a NAS path, make sure the NAS is mounted."
}
if (-not (Test-Path -LiteralPath $To -PathType Container)) {
    if ($PSCmdlet.ShouldProcess($To, 'Create user data directory')) {
        New-Item -Path $To -ItemType Directory -Force | Out-Null
    }
}
# GetFullPath works under -WhatIf, when the directory has not been created.
$toPath = [System.IO.Path]::GetFullPath($To)

if ($fromPath -eq $toPath) {
    throw "Source and destination are the same directory ('$fromPath'). Configure a different userDataRoot first."
}

$fromPrograms = [System.IO.Path]::Join($fromPath, 'programs')
if (-not (Test-Path -LiteralPath $fromPrograms -PathType Container)) {
    Write-Host "No 'programs' directory in '$fromPath'; nothing to migrate."
    return
}

$copied = 0
$skipped = 0
$repaired = 0
$failed = 0

foreach ($program in Get-ChildItem -LiteralPath $fromPrograms -Directory) {
    $programName = $program.Name
    $destinationProgram = [System.IO.Path]::Join($toPath, 'programs', $programName)

    if (-not (Test-Path -LiteralPath $destinationProgram -PathType Container)) {
        if ($PSCmdlet.ShouldProcess($destinationProgram, 'Create directory')) {
            New-Item -Path $destinationProgram -ItemType Directory -Force | Out-Null
        }
    }

    # Copy regular files only. Per-run scratch directories (tmp/) are
    # regenerated at launch, and .desktop files are machine-local and are
    # recreated by Install.ps1.
    foreach ($file in Get-ChildItem -LiteralPath $program.FullName -File) {
        if ($file.Extension -eq '.desktop') {
            $skipped++
            continue
        }

        $destinationFile = [System.IO.Path]::Join($destinationProgram, $file.Name)
        if ((Test-Path -LiteralPath $destinationFile) -and -not $Force) {
            Write-Warning "Skipping '$destinationFile' because it already exists (use -Force to overwrite)."
            $skipped++
            continue
        }

        if ($PSCmdlet.ShouldProcess($destinationFile, "Copy from '$($file.FullName)'")) {
            Copy-Item -LiteralPath $file.FullName -Destination $destinationFile -Force
            $copied++
        }
    }

    $destinationHdd = [System.IO.Path]::Join($destinationProgram, 'hdd.vhd')
    $parentHdd = [System.IO.Path]::Join($ProgramsRoot, $programName, 'hdd.vhd')

    if (-not (Test-Path -LiteralPath $destinationHdd -PathType Leaf)) {
        continue
    }
    if (-not (Test-Path -LiteralPath $parentHdd -PathType Leaf)) {
        Write-Warning "Cannot repair '$destinationHdd': parent image '$parentHdd' was not found."
        $failed++
        continue
    }

    try {
        $result = Update-VhdParentPath -ChildPath $destinationHdd -ParentPath $parentHdd -Confirm:$false -WhatIf:$WhatIfPreference
        if ($null -eq $result) {
            # -WhatIf: Update-VhdParentPath already printed what it would do.
            continue
        }
        if ($result.Updated) {
            Write-Host "Repaired the parent path for '$programName'."
            $repaired++
        } else {
            Write-Host "The parent path for '$programName' is already correct."
        }
    } catch {
        Write-Warning "Could not repair '$destinationHdd': $($_.Exception.Message)"
        $failed++
    }
}

Write-Host "Copied $copied file(s), skipped $skipped, repaired $repaired VHD(s), failed $failed."
if ($failed -gt 0) {
    throw "$failed VHD(s) could not be repaired. The source data was not changed."
}
