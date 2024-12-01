function New-DesktopEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProgramDirName,

        [Parameter(Mandatory = $true)]
        [string]$ProgramName,

        [Parameter(Mandatory = $true)]
        [string]$IconPath
    )

    $rootPath = Get-OldGamesRoot
    $startProgramScriptPath = [System.IO.Path]::Join($rootPath, "Start-Program.ps1")
    $programDir = [System.IO.Path]::Join($rootPath, "programs", $ProgramDirName)
    if (-not (Test-Path -Path $programDir)) {
        throw "Program directory '$programDir' does not exist."
    }

    $desktopEntryPath = [System.IO.Path]::Join($programDir, "$ProgramDirName.desktop")

    $desktopEntry = @"
[Desktop Entry]
Name=$ProgramName
Exec=$startProgramScriptPath $ProgramDirName
Icon=$IconPath
Type=Application
Categories=Game;
Terminal=false
"@

    Set-Content -Path $desktopEntryPath -Value $desktopEntry
}
