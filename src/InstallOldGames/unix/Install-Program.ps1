function Install-Program {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProgramDirName,

        [Parameter(Mandatory = $true)]
        [ValidateSet('user','system')]
        [string]$InstallScope,

        # How to launch DOSBox-X. Defaults to $env:OLDGAMES_DOSBOX_X or 'dosbox-x'.
        [Parameter()]
        [string[]]$DosBoxXCommand
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
        Get-ProgramIcon -ProgramDirName $ProgramDirName -DosBoxXCommand $DosBoxXCommand
    }

    Write-Host "Creating desktop entry..."
    New-DesktopEntry -ProgramDirName $ProgramDirName -ProgramName $fullProgramName -IconPath $iconPath -Scope $InstallScope -DosBoxXCommand $DosBoxXCommand
}
