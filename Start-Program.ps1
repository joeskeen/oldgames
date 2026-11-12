#!/usr/bin/env pwsh

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProgramDirName,

    [Parameter()]
    [switch]$NoExit,

    # How to launch DOSBox-X. Defaults to $env:OLDGAMES_DOSBOX_X or 'dosbox-x'.
    # For a Flatpak install: -DosBoxXCommand 'flatpak run com.dosbox_x.DOSBox-X'
    [Parameter()]
    [string[]]$DosBoxXCommand,

    # Where per-user savedata lives. Overrides /etc/oldgames/config.json,
    # ~/.config/oldgames/config.json and OLDGAMES_USER_DATA_ROOT. See
    # Get-OldGamesConfig for the full precedence order.
    [Parameter()]
    [string]$UserDataRoot
)

Import-Module "$PSScriptRoot/src/PSDosBoxXConf" -Force
Import-Module "$PSScriptRoot/src/InstallOldGames" -Force

$programDir = "$PSScriptRoot/programs/$ProgramDirName"
if (-not (Test-Path -Path $programDir)) {
    Write-Error "The program directory '$programDir' does not exist."
    return
}
$discImages = Get-ChildItem -Path $programDir -File | Where-Object { $_.Extension -in ".iso",".cue" } | Sort-Object -Property Name

$oldGamesConfig = Get-OldGamesConfig -UserDataRoot $UserDataRoot
$userDir = $oldGamesConfig.UserDataRoot
if (-not (Test-Path -Path $userDir)) {
    $userDirParent = Split-Path -Parent $userDir
    if (-not (Test-Path -LiteralPath $userDirParent)) {
        if ($oldGamesConfig.IsDefault) {
            New-Item -Path $userDirParent -ItemType Directory -Force | Out-Null
        } else {
            Write-Error "The user data directory '$userDir' is not available because its parent '$userDirParent' does not exist. If this is a NAS path, make sure the NAS is mounted."
            return
        }
    }
    New-Item -Path $userDir -ItemType Directory -Force | Out-Null
}
$userProgramDir = "$userDir/programs/$ProgramDirName"
if (-not (Test-Path -Path $userProgramDir)) {
    New-Item -Path $userProgramDir -ItemType Directory -Force | Out-Null
}
$relativeProgramDir = Resolve-Path -Path $programDir -Relative -RelativeBasePath $userProgramDir

$dosboxX = Get-DosBoxXCommand -Command $DosBoxXCommand

$fullProgramName = Get-ProgramFullName -ProgramDirName $ProgramDirName
Write-Host "Starting program '$fullProgramName'..."

$baseConfPath = "$programDir/dosbox-x.conf"

$baseConf = Import-DosBoxXConf -Path $baseConfPath
$target = $baseConf | Get-ConfigOption -SectionName 'config' -OptionName 'set TARGET'
if (-not $target) {
    Write-Error "The 'TARGET' option is not set in the install configuration."
    return
}
$target = $target.Trim()

# The TARGET value is a Windows path to the program, optionally followed by
# command-line arguments, e.g. 'C:\GAMES\DOOM\DOOM.EXE -warp 1'. Paths with
# spaces are quoted, as they appear in the Windows 98 properties dialog.
$exePath = $null
$rest = ''

$quotedMatch = [regex]::Match($target, '^(?<exe>"[^"]+")(?<rest>\s.*)?$')
if ($quotedMatch.Success) {
    $exePath = $quotedMatch.Groups['exe'].Value.Trim('"')
    $rest = $quotedMatch.Groups['rest'].Value.Trim()
} else {
    # The path may contain more than one '.exe', so match the first occurrence
    # that is followed by whitespace or the end of the string, case-insensitively
    # ('.EXE' is just as valid as '.exe' on Windows 9x).
    $exeMatch = [regex]::Match(
        $target,
        '^(?<exe>.+?\.exe)(?<rest>\s.*)?$',
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    )
    if ($exeMatch.Success) {
        $exePath = $exeMatch.Groups['exe'].Value
        $rest = $exeMatch.Groups['rest'].Value.Trim()
    } else {
        # Not an .exe (e.g. a .bat or .com launcher): the first token is the
        # program and everything after it is the argument list.
        $targetParts = $target -split '\s+', 2
        $exePath = $targetParts[0]
        $rest = if ($targetParts.Count -gt 1) { $targetParts[1].Trim() } else { '' }
    }
}

$targetDir = if ($exePath.Contains('\')) {
    $exePath.Substring(0, $exePath.LastIndexOf('\'))
} else {
    ''
}

$tmpDir = "$userProgramDir/tmp"
if (-not (Test-Path -Path $tmpDir)) {
    New-Item -Path $tmpDir -ItemType Directory -Force | Out-Null
}

$envType = $baseConf | Get-ConfigOption -SectionName 'config' -OptionName 'set ENV_TYPE'
if (-not $envType) {
    # Programs installed before environment types existed are Windows 9x.
    $envType = 'win9x'
}
$envType = $envType.Trim().ToLower()

switch ($envType) {
    'dos' {
        $dosMode = $baseConf | Get-ConfigOption -SectionName 'config' -OptionName 'set DOS_MODE'
        if (-not $dosMode) { $dosMode = 'shell' }
        $dosMode = $dosMode.Trim().ToLower()

        if ($dosMode -eq 'boot') {
            # CDVOL.COM mirrors the guest's MSCDEX CD volume command to the
            # Sound Blaster mixer; DOSBox-X ignores the guest ATAPI volume.
            Copy-Item -Path "$PSScriptRoot/utils/cdvol/CDVOL.COM" -Destination "$tmpDir/CDVOL.COM" -Force
        }

        $plan = Get-DosLaunchPlan `
            -Mode $dosMode `
            -RelativeProgramDir $relativeProgramDir `
            -DiscImageNames ($discImages | ForEach-Object { $_.Name }) `
            -TargetDir $targetDir `
            -ExePath $exePath `
            -Rest $rest `
            -TmpDir $tmpDir `
            -ExitWhenDone:(-not $NoExit.IsPresent)

        foreach ($fileName in $plan.Files.Keys) {
            $plan.Files[$fileName] | Out-File -FilePath "$tmpDir/$fileName" -Encoding ascii
        }
        $autoexec = $plan.AutoExec
    }
    'win9x' {
$runBatPath = "$tmpDir/run.bat" # This is run in MS-DOS
$runBat = @"
@echo on
CLS
C:
REM LOADCD.BAT
win A:\PROG.BAT
echo Done (this line needs to be here or the 'win' command will not work for some reason)
"@.Trim() -replace "\r?\n", "`r`n" # IMPORTANT: must use DOS line endings or it won't work
$runBat | Out-File -FilePath $runBatPath -Encoding ascii

$progBatPath = "$tmpDir/prog.bat" # This is run in Windows 98
$cdLine = if ($targetDir) { "CD `"$targetDir`"" } else { 'REM The target has no directory to switch to' }
$progBat = @"
@echo off
ECHO Starting "$fullProgramName"...
$cdLine
START /WAIT "$exePath" $rest
REM PAUSE
$(
    if (!$NoExit.ToBool()) { 
        'C:\WINDOWS\RUNDLL32.EXE SHELL32.DLL,SHExitWindowsEx 1' 
    }
)
"@.Trim() -replace "\r?\n", "`r`n" # IMPORTANT: must use DOS line endings or it won't work
$progBat | Out-File -FilePath $progBatPath -Encoding ascii

# This is run in DosBox-X shell
$autoexec = @"
@echo on
cls

# create the user's savedata hard drive image based on the game install image
vhdmake -l $relativeProgramDir/hdd.vhd hdd.vhd
imgmount c hdd.vhd

# mount the game disc image(s)
$($discImages | ForEach-Object { "imgmount d `"$relativeProgramDir/$($_.Name)`" " })

# Create a temp floppy image that will help with running the program
# Files from the tmp dir will be copied to the floppy image
# We do this instead of using the tmp dir directly because the tmp dir directly
# as when we boot the guest OS, any mounted directories become converted to
# a image, and no changes are persisted. By using a floppy image, we can
# detect on the host OS that the guest OS has made a change to the contents of the floppy
imgmake -t fd_1440 fd.img -force
imgmount a -t floppy fd.img -nocachedir
mount b $tmpDir
COPY B:\RUN.BAT A:\
COPY B:\PROG.BAT A:\
COPY Z:\BIN\SHUTDOWN.COM A:\
mount -u b
mount b $PSScriptRoot/utils -t floppy
COPY B:\ATM\ATM30.EXE A:\
mount -u b

# Make it so that when the guest OS boots, it will run the A:\RUN.BAT script
ECHO A:\RUN.BAT > C:\AUTOEXEC.BAT

# Modify the MSDOS.SYS file so that the guest OS boots to the command prompt 
# (so we are not stuck in Windows, requiring a user to manually "shutdown" the guest OS)
COPY C:\MSDOS.SYS C:\MSDOS.BAK /Y
DEL C:\MSDOS.SYS /F
C:\WINDOWS\SYSTEM32\SED.EXE "s/BootGUI=1/BootGUI=0/g" C:\MSDOS.BAK > C:\MSDOS.SYS

mount
imgmount
ECHO Run "BOOT C:" to start the program
BOOT C:
"@
    }
    default {
        Write-Error "Unsupported environment type '$envType' in '$baseConfPath'."
        return
    }
}

$config = $baseConf

# The OpenCode MCP integration publishes the live debugger-control port here
# (one server per client, so it is not always the default 58991). This is
# machine-local state, so it deliberately stays under $HOME even when user
# data lives on a NAS.
$mcpPortFile = [System.IO.Path]::Join($HOME, '.config', 'oldgames', 'dosbox-mcp-port')
if (Test-Path -Path $mcpPortFile) {
    $mcpPort = (Get-Content -Path $mcpPortFile -Raw).Trim()
    if ($mcpPort -match '^\d+$') {
        $config = $config | Set-ConfigOption -SectionName 'dosbox' -OptionName 'mcp_server' -Value $mcpPort
    }
}

$config = $config | Set-ConfigOption -SectionName 'autoexec' -Value $autoexec

$config | Export-DosBoxXConf -Path "$userProgramDir/user.dosbox-x.conf"

Start-DosBoxX -Command $dosboxX -WorkingDirectory $userProgramDir -Arguments @('-conf', 'user.dosbox-x.conf') -Wait
