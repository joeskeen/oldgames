function Get-ProgramIcon {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProgramDirName,

        [Parameter(Mandatory = $false)]
        [switch]$Force,

        # How to launch DOSBox-X. Defaults to $env:OLDGAMES_DOSBOX_X or 'dosbox-x'.
        [Parameter()]
        [string[]]$DosBoxXCommand
    )

    $root = Get-OldGamesRoot
    $programDir = [System.IO.Path]::Join($root, "programs", $ProgramDirName)

    if (-not (Test-Path -Path $programDir)) {
        throw "Program directory '$programDir' does not exist."
    }

    $dosboxX = Get-DosBoxXCommand -Command $DosBoxXCommand

    $hasWrestool = $null -ne (Get-Command wrestool -ErrorAction SilentlyContinue)
    $hasConvert = $null -ne (Get-Command convert -ErrorAction SilentlyContinue)
    if (-not $hasWrestool) {
        Write-Warning "wrestool was not found (install icoutils); only .ICO files can be extracted from the images."
    }
    if (-not $hasConvert) {
        Write-Warning "ImageMagick's convert was not found; an icon cannot be generated."
        return
    }

    $iconPath = [System.IO.Path]::Join($programDir, "icon.png")
    if ((Test-Path -Path $iconPath) -and -not $Force) {
        Write-Host "Found icon at '$iconPath'."
        return
    }

    $searchImgs = @((Get-ChildItem -Path $programDir | Where-Object { $_.Extension -in @('.iso', '.img', '.cue') } | ForEach-Object { $_.FullName }), "$programDir/hdd.vhd") | ForEach-Object { $_ }
    foreach ($img in $searchImgs) {
        Write-Host "Searching for icons in '$($img)'..."
        # Keep the mount point inside $HOME: Flatpak apps get a private /tmp,
        # so files DOSBox-X writes under /tmp would never reach this script.
        $mountPoint = [System.IO.Path]::Join($HOME, '.cache', 'oldgames', 'icon-search')
        $iconDir = [System.IO.Path]::Join($mountPoint, 'icons')
        if (Test-Path -Path $mountPoint) {
            Get-ChildItem -Path $mountPoint -Force | Remove-Item -Recurse -Force
        }
        New-Item -Path $iconDir -ItemType Directory -Force | Out-Null
        $commands = @" 
            imgmount c "$($img)" -ro
            mount d "$mountPoint" -nocachedir
            XCOPY C:\*.ICO D:\ /S /Y
            XCOPY C:\*.EXE D:\ /S /Y
            DELTREE D:\WINDOWS /Y
            DELTREE D:\WIN98 /Y
            DELTREE D:\DRIVERS /Y
            DELTREE D:\TOOLS /Y
            DELTREE D:\PROGRA~1\ACCESS~1 /Y
            DELTREE D:\PROGRA~1\COMMON~1 /Y
            DELTREE D:\PROGRA~1\INTERN~1 /Y
            DELTREE D:\PROGRA~1\NETMEE~1 /Y
            DELTREE D:\PROGRA~1\ONLINE~1 /Y
            DELTREE D:\PROGRA~1\OUTLOO~1 /Y
            DELTREE D:\PROGRA~1\PLUS! /Y
            DELTREE D:\PROGRA~1\WINDOW~1 /Y
"@ -split [System.Environment]::NewLine  | ForEach-Object { "-c `"$($_.Trim().Replace('"', '\"'))`"" }
        $pargs = "-silent $($commands -join ' ')"
        Write-Host "Running '$($dosboxX.FilePath) $($dosboxX.Arguments -join ' ') $pargs'..."
        Start-DosBoxX -Command $dosboxX -Arguments @($pargs) -Wait
        if ($hasWrestool) {
            $exeFiles = Get-ChildItem -Path $mountPoint -Recurse -Include "*.EXE", "*.exe" | Where-Object { $_.FullName -notlike "*windows*" -and $_.FullName -notlike "*win98*" }
            $exeFiles | ForEach-Object {
                $exe = $_
                $icons = wrestool -l $exe.FullName --type=14 | ForEach-Object { [System.Text.RegularExpressions.Regex]::Match($_, "--name=([^ ]*)").Groups[1].Value }
                foreach ($icon in $icons) {
                    $target = "$iconDir/$($exe.Name).$icon.ico"
                    wrestool -x $exe.FullName --type=14 --name=$icon > $target
                    if ((Test-Path -Path $target) -and -not (Get-Item $target).Length) {
                        Remove-Item $target
                    }
                }
                $target = "$iconDir/$($exe.Name).ico"
                wrestool -x $exe.FullName > $target
                if ((Test-Path -Path $target) -and -not (Get-Item $target).Length) {
                    Remove-Item $target
                }
            }
        }
        $allIcons = Get-ChildItem -Path $mountPoint -Recurse -Include '*.ICO', '*.ico' | Where-Object { $_.FullName -notlike "*windows*" -and $_.FullName -notlike "*win98*" } | Sort-Object { $_.Name }
        Write-Host @"
Choose which icon to use:
0) None of these
"@
        for ($i = 1; $i -le $allIcons.Length; $i++) {
            $icon = $allIcons[$i - 1]
            $iconName = $icon.FullName
            Write-Host "$i) $iconName"
        }
        $iconChoice = [int](Read-Host "Enter the number of the icon to use (0-$($allIcons.Length))")
        if ($iconChoice -gt 0) {
            $iconFile = $allIcons[$iconChoice - 1].FullName
            $outputFile = "$programDir/icon.png"
            $size = 256
            convert -background none -filter Point -resize x${size} -gravity center -crop ${size}x${size}+0+0 "$iconFile" -flatten -colors 256 "$outputFile"
            break
        }
    }
}