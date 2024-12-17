function Install-Program {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProgramDirName,

        [Parameter(Mandatory = $true)]
        [ValidateSet('user','system')]
        [string]$InstallScope
    )

    $root = Get-OldGamesRoot
    $programDir = [System.IO.Path]::Join($root, "programs", $ProgramDirName)
    if (-not (Test-Path -Path $programDir)) {
        throw "Program directory '$programDir' does not exist."
    }

    $fullProgramName = Get-ProgramFullName -ProgramDirName $ProgramDirName

    $iconPath = [System.IO.Path]::Join($programDir, "icon.png")
    if (-not (Test-Path -Path $iconPath)) {
        Write-Host "Program icon not found. Searching..."
        Get-ProgramIcon -ProgramDirName $ProgramDirName
    }

    $desktopEntrySrcDir = switch($InstallScope) {
        'system' {
            $programDir
        }
        'user' {
            "$HOME/.config/oldgames/programs/$ProgramDirName"
        }
    }
    $desktopEntryPath = [System.IO.Path]::Join($desktopEntrySrcDir, "$ProgramDirName.desktop")
    if (-not (Test-Path -Path $desktopEntryPath)) {
        Write-Host "Creating desktop entry..."
        New-DesktopEntry -ProgramDirName $ProgramDirName -ProgramName $fullProgramName -IconPath $iconPath -Scope $InstallScope
    }
    $desktopEntryDir = switch($InstallScope) {
        'system' {
            "/usr/share/applications"
        }
        'user' {
            "$HOME/.local/share/applications"
        }
    }
    if (-not (Test-Path -Path $desktopEntryDir)) {
        mkdir -p $desktopEntryDir
    }
    $desktopEntryDest = [System.IO.Path]::Join($desktopEntryDir, "$ProgramDirName.desktop")
    
    cp $desktopEntryPath $desktopEntryDest
}