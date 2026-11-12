function New-DesktopEntry {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProgramDirName,

        [Parameter(Mandatory = $true)]
        [string]$ProgramName,

        [Parameter(Mandatory = $true)]
        [string]$IconPath,

        # 'user' writes to ~/.local/share/applications (per machine);
        # 'system' writes to /usr/share/applications (all accounts on the
        # machine, requires write access there).
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

    # Desktop entries are machine-local: they name the Start-Program.ps1 path
    # and, optionally, the DOSBox-X command for this machine. They must not be
    # stored in the shared per-user data directory on a NAS.
    $desktopEntryDir = switch($Scope) {
        'system' {
            "/usr/share/applications"
        }
        'user' {
            [System.IO.Path]::Join($HOME, ".local", "share", "applications")
        }
    }

    if (-not (Test-Path -Path $desktopEntryDir)) {
        New-Item -Path $desktopEntryDir -ItemType Directory -Force | Out-Null
    }

    $desktopEntryPath = [System.IO.Path]::Join($desktopEntryDir, "$ProgramDirName.desktop")

    # Invoke pwsh explicitly rather than relying on the script's shebang. This
    # keeps the entry working when the repository is on a noexec NAS mount and
    # does not depend on the script's executable bit.
    $resolvedPwsh = Get-Command -Name pwsh -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($resolvedPwsh) {
        $pwshPath = $resolvedPwsh.Source
    } else {
        $pwshPath = [System.IO.Path]::Join($PSHOME, 'pwsh')
        if (-not (Test-Path -LiteralPath $pwshPath)) {
            throw "Could not find the pwsh executable to embed in the desktop entry."
        }
    }

    $execCommand = "`"$pwshPath`" `"$startProgramScriptPath`" `"$ProgramDirName`""
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

    if ($PSCmdlet.ShouldProcess($desktopEntryPath, 'Write desktop entry')) {
        Set-Content -Path $desktopEntryPath -Value $desktopEntry
    }
    Write-Output $desktopEntryPath
}
