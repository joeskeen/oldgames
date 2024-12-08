#!/usr/bin/env pwsh

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProgramName,

    [Parameter()]
    # [ValidateSet('win9x','win3x', 'dos')] # TODO: Add support for Windows 3.x and DOS
    [ValidateSet('win9x')]
    [string]$EnvType = 'win9x',

    [Parameter()]
    [string[]]$DiskImagePaths = @()
)

Import-Module "$PSScriptRoot/src/PSDosBoxXConf" -Force
Import-Module "$PSScriptRoot/src/InstallOldGames" -Force

$normalizedName = $ProgramName.Trim().ToLower() -replace '[^A-Za-z0-9]', '-'
$programDir = "$PSScriptRoot/programs/$normalizedName"
if (-not (Test-Path -Path $programDir)) {
    New-Item -Path $programDir -ItemType Directory
}

$DiskImages = $DiskImagePaths | ForEach-Object { 
    (Copy-Item -Path $_ -Destination $programDir -PassThru).Name 
}

$hddImgName = "hdd.vhd"

$envDir = "$PSScriptRoot/envs/$EnvType"
$envSettings = @{
    BaseConfPath = "$envDir/dosbox-x.conf"
    BaseHddImg = "$envDir/hdd.vhd"
}

$progHddImg = "$programDir/$hddImgName"
if ((Test-Path -Path $progHddImg) -and (Read-Host "A hard drive image already exists. Overwrite? (y/n)") -eq 'y') {
    Remove-Item -Path $progHddImg    
}

$baseImgRelativePath = Resolve-Path -Path $envSettings.BaseHddImg -Relative -RelativeBasePath $programDir

$installAutoexec = @"
cls
vhdmake -l $baseImgRelativePath $hddImgName
imgmount c $hddImgName
$($DiskImages | ForEach-Object { "imgmount d `"$_`" -t cdrom" })
mount
BOOT C:
"@

$installConfig = Import-DosBoxXConf -Path $envSettings.BaseConfPath
| Set-ConfigOption -SectionName 'dosbox' -OptionName 'title' -Value "Install '$ProgramName'"
| Set-ConfigOption -SectionName 'autoexec' -Value $installAutoexec

$progInstallConfPath = "$programDir/install.dosbox-x.conf"
$installConfig | Export-DosBoxXConf -Path $progInstallConfPath

do {
    Start-Process -WorkingDirectory $programDir -FilePath "dosbox-x" -ArgumentList "-conf $progInstallConfPath" -Wait
} while ((Read-Host "Reboot DosBox-X to finish installing? (y/n)") -ne 'n')

$programCommand = Read-Host "Enter the command to run the program (full path)"
$runAutoexec = @"
imgmount c $hddImgName
$($DiskImages | ForEach-Object { "imgmount d `"$_`" -t cdrom -ide 2m" })
BOOT C:
"@
$runConfig = Import-DosBoxXConf -Path $progInstallConfPath
| Set-ConfigOption -SectionName 'sdl' -OptionName 'fullscreen' -Value 'true'
| Set-ConfigOption -SectionName 'sdl' -OptionName 'fullresolution' -Value 'desktop'
| Set-ConfigOption -SectionName 'sdl' -OptionName 'output' -Value 'opengl'
| Set-ConfigOption -SectionName 'sdl' -OptionName 'aspect' -Value 'true'
| Set-ConfigOption -SectionName 'dosbox' -OptionName 'title' -Value "$ProgramName"
| Set-ConfigOption -SectionName 'config' -OptionName 'set TARGET' -Value $programCommand
| Set-ConfigOption -SectionName 'autoexec' -Value $runAutoexec

Export-DosBoxXConf -Config $runConfig -Path "$programDir/dosbox-x.conf"

$ProgramName | Out-File -FilePath "$programDir/program-name.txt"

Get-ProgramIcon -ProgramDirName $normalizedName
