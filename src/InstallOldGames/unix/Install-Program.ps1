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

    $desktopEntryPath = [System.IO.Path]::Join($programDir, "$ProgramDirName.desktop")
    if (-not (Test-Path -Path $desktopEntryPath)) {
        Write-Host "Creating desktop entry..."
        New-DesktopEntry -ProgramDirName $ProgramDirName -ProgramName $fullProgramName -IconPath $iconPath
    }
    if ($InstallScope -eq 'system') {
        $desktopEntryDest = "/usr/share/applications/$ProgramDirName.desktop"
        sudo cp $desktopEntryPath $desktopEntryDest
    } else {
        $desktopEntryDest = "$HOME/.local/share/applications/$ProgramDirName.desktop"
        cp $desktopEntryPath $desktopEntryDest
    }
}