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
    [string[]]$DosBoxXCommand
)

$programDir = "$PSScriptRoot/programs/$ProgramDirName"
if (-not (Test-Path -Path $programDir)) {
    Write-Error "The program directory '$programDir' does not exist."
    return
}
$discImages = Get-ChildItem -Path $programDir -File | Where-Object { $_.Extension -in ".iso",".cue" } | Sort-Object -Property Name

$userDir = "~/.config/oldgames"
if (-not (Test-Path -Path $userDir)) {
    New-Item -Path $userDir -ItemType Directory -Force | Out-Null
}
$userProgramDir = "$userDir/programs/$ProgramDirName"
if (-not (Test-Path -Path $userProgramDir)) {
    New-Item -Path $userProgramDir -ItemType Directory -Force | Out-Null
}
$relativeProgramDir = Resolve-Path -Path $programDir -Relative -RelativeBasePath $userProgramDir

Import-Module "$PSScriptRoot/src/PSDosBoxXConf" -Force
Import-Module "$PSScriptRoot/src/InstallOldGames" -Force

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

$config = $baseConf
| Set-ConfigOption -SectionName 'autoexec' -Value $autoexec

$config | Export-DosBoxXConf -Path "$userProgramDir/user.dosbox-x.conf"

$dosboxArgs = @($dosboxX.Arguments) + @('-conf', 'user.dosbox-x.conf')
Start-Process -WorkingDirectory $userProgramDir -FilePath $dosboxX.FilePath -ArgumentList $dosboxArgs -Wait
