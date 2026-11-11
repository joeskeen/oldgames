function New-DesktopEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProgramDirName,

        [Parameter(Mandatory = $true)]
        [string]$ProgramName,

        [Parameter(Mandatory = $true)]
        [string]$IconPath,

        [Parameter()]
        [ValidateSet('user','system')]
        [string]$Scope = 'user',

        # How to launch DOSBox-X. Embedded into the desktop entry so that it
        # works even when the desktop session does not have OLDGAMES_DOSBOX_X
        # set (desktop entries do not inherit variables from your shell).
        [Parameter()]
        [string[]]$DosBoxXCommand
    )

    $rootPath = Get-OldGamesRoot
    $startProgramScriptPath = [System.IO.Path]::Join($rootPath, "Start-Program.ps1")
    $programDir = [System.IO.Path]::Join($rootPath, "programs", $ProgramDirName)
    if (-not (Test-Path -Path $programDir)) {
        throw "Program directory '$programDir' does not exist."
    }

    $desktopEntryDir = switch($Scope) {
        'system' {
            $programDir
        }
        'user' {
            [System.IO.Path]::Join($HOME, ".config/oldgames/programs/$ProgramDirName")
        }
    }

    if (-not (Test-Path -Path $desktopEntryDir)) {
        New-Item -Path $desktopEntryDir -ItemType Directory -Force
    }

    $desktopEntryPath = [System.IO.Path]::Join($desktopEntryDir, "$ProgramDirName.desktop")

    $execCommand = "`"$startProgramScriptPath`" $ProgramDirName"
    if ($DosBoxXCommand) {
        $execCommand += " -DosBoxXCommand `"$($DosBoxXCommand -join ' ')`""
    }

    $desktopEntry = @"
[Desktop Entry]
Name=$ProgramName
Exec=$execCommand
Icon=$IconPath
Type=Application
Categories=Game;
Terminal=false
"@

    Set-Content -Path $desktopEntryPath -Value $desktopEntry
}
