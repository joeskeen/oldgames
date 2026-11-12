#!/usr/bin/env pwsh

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProgramName,

    [Parameter()]
    # TODO: Add support for Windows 3.x ('win3x')
    [ValidateSet('win9x', 'dos')]
    [string]$EnvType = 'win9x',

    # DOS only: 'shell' runs the game from DOSBox-X's built-in DOS, 'boot'
    # boots the DOS disk image first (some games only behave correctly then).
    [Parameter()]
    [ValidateSet('shell', 'boot')]
    [string]$DosMode = 'shell',

    [Parameter()]
    [string[]]$DiskImagePaths = @(),

    # How to launch DOSBox-X. Defaults to $env:OLDGAMES_DOSBOX_X or 'dosbox-x'.
    # For a Flatpak install: -DosBoxXCommand 'flatpak run com.dosbox_x.DOSBox-X'
    [Parameter()]
    [string[]]$DosBoxXCommand
)

Import-Module "$PSScriptRoot/src/PSDosBoxXConf" -Force
Import-Module "$PSScriptRoot/src/InstallOldGames" -Force

$dosboxX = Get-DosBoxXCommand -Command $DosBoxXCommand

$normalizedName = $ProgramName.Trim().ToLower() -replace '[^A-Za-z0-9]', '-'
if ($ProgramName -match '\.(iso|cue|bin|img|ima)$' -or (Test-Path -LiteralPath $ProgramName)) {
    throw "The first argument is the program name, not a disc image. Use -DiskImagePaths for the image, e.g.:`n  ./New-Program.ps1 -ProgramName 'My Game' -DiskImagePaths '$ProgramName'"
}
$programDir = "$PSScriptRoot/programs/$normalizedName"
if (-not (Test-Path -Path $programDir)) {
    New-Item -Path $programDir -ItemType Directory
}

$DiskImages = $DiskImagePaths | ForEach-Object {
    Import-DiskImage -Path $_ -DestinationDir $programDir
}

$hddImgName = "hdd.vhd"

$envDir = "$PSScriptRoot/envs/$EnvType"
$envSettings = @{
    BaseConfPath = "$envDir/dosbox-x.conf"
    BaseHddImg = "$envDir/hdd.vhd"
}

if (-not (Test-Path -Path $envSettings.BaseConfPath)) {
    Write-Error "The base DOSBox-X configuration '$($envSettings.BaseConfPath)' does not exist."
    return
}
if (-not (Test-Path -Path $envSettings.BaseHddImg)) {
    Write-Error "The base hard drive image '$($envSettings.BaseHddImg)' does not exist. Complete the initial setup for the '$EnvType' environment described in the Readme first."
    return
}

$progHddImg = "$programDir/$hddImgName"
$installProgram = $true
if (Test-Path -Path $progHddImg) {
    if ((Read-Host "A hard drive image already exists. Overwrite? (y/n)") -eq 'y') {
        Remove-Item -Path $progHddImg
    } else {
        Write-Host "Using the existing hard drive image (skipping the install step)."
        $installProgram = $false
    }
}

$baseImgRelativePath = Resolve-Path -Path $envSettings.BaseHddImg -Relative -RelativeBasePath $programDir

$installAutoexec = @"
cls
vhdmake -l $baseImgRelativePath $hddImgName
imgmount c $hddImgName
$($DiskImages | ForEach-Object { "imgmount d `"$_`" -t cdrom -ide 2m" })
mount
BOOT C:
"@

$installConfig = Import-DosBoxXConf -Path $envSettings.BaseConfPath
| Set-ConfigOption -SectionName 'dosbox' -OptionName 'title' -Value "Install '$ProgramName'"
| Set-ConfigOption -SectionName 'autoexec' -Value $installAutoexec

$progInstallConfPath = "$programDir/install.dosbox-x.conf"
$installConfig | Export-DosBoxXConf -Path $progInstallConfPath

$installArgs = @('-conf', "`"$progInstallConfPath`"")
if ($installProgram) {
    do {
        Start-DosBoxX -Command $dosboxX -WorkingDirectory $programDir -Arguments $installArgs -Wait
    } while ((Read-Host "Reboot DosBox-X to finish installing? (y/n)") -ne 'n')
}

$programCommand = Read-Host "Enter the command to run the program (full path)"
$runAutoexec = @"
imgmount c $hddImgName
$($DiskImages | ForEach-Object { "imgmount d `"$_`" -t cdrom" })
BOOT C:
"@
$runConfig = Import-DosBoxXConf -Path $progInstallConfPath
| Set-ConfigOption -SectionName 'sdl' -OptionName 'fullscreen' -Value 'true'
| Set-ConfigOption -SectionName 'sdl' -OptionName 'fullresolution' -Value 'desktop'
| Set-ConfigOption -SectionName 'sdl' -OptionName 'output' -Value 'opengl'
| Set-ConfigOption -SectionName 'sdl' -OptionName 'aspect' -Value 'true'
| Set-ConfigOption -SectionName 'dosbox' -OptionName 'title' -Value "$ProgramName"
| Set-ConfigOption -SectionName 'config' -OptionName 'set TARGET' -Value $programCommand
| Set-ConfigOption -SectionName 'config' -OptionName 'set ENV_TYPE' -Value $EnvType
| Set-ConfigOption -SectionName 'autoexec' -Value $runAutoexec

if ($EnvType -eq 'dos') {
    $runConfig = $runConfig | Set-ConfigOption -SectionName 'config' -OptionName 'set DOS_MODE' -Value $DosMode
}

Export-DosBoxXConf -Config $runConfig -Path "$programDir/dosbox-x.conf"

$ProgramName | Out-File -FilePath "$programDir/program-name.txt"

if ($EnvType -eq 'dos') {
    Write-Host "Skipping icon extraction: DOS executables do not contain icon resources."
} else {
    Get-ProgramIcon -ProgramDirName $normalizedName -DosBoxXCommand $DosBoxXCommand
}
