#!/usr/bin/env pwsh

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProgramDirName,

    [Parameter()]
    [switch]$NoExit
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

$fullProgramName = Get-ProgramFullName -ProgramDirName $ProgramDirName
Write-Host "Starting program '$fullProgramName'..."

$baseConfPath = "$programDir/dosbox-x.conf"

$baseConf = Import-DosBoxXConf -Path $baseConfPath
$target = ($baseConf | Get-ConfigOption -SectionName 'config' -OptionName 'set TARGET').Trim()
if (-not $target) {
    Write-Error "The 'TARGET' option is not set in the install configuration."
    return
}
$targetDir = $target.Substring(0, $target.LastIndexOf("\"))

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
$progBat = @"
@echo off
ECHO Starting "$fullProgramName"...
CD "$targetDir"
START /WAIT "$($target.Trim())"
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

Start-Process -WorkingDirectory $userProgramDir -FilePath "dosbox-x" -ArgumentList "-conf user.dosbox-x.conf" -Wait
