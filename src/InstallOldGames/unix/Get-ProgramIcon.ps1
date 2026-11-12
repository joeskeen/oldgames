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

    # DOS executables have no PE/NE resources. New-Program skips their icon
    # extraction for that reason; do not mount the game CD and prompt for an
    # icon from the disc's autoplay files.
    $programConfPath = [System.IO.Path]::Join($programDir, 'dosbox-x.conf')
    if (Test-Path -Path $programConfPath) {
        $isDos = Get-Content -Path $programConfPath -ErrorAction SilentlyContinue |
            Select-String -Pattern '^\s*set\s+ENV_TYPE\s*=\s*dos\s*$' -Quiet
        if ($isDos) {
            Write-Host "DOS program; skipping icon search."
            return
        }
    }

    $dosboxX = Get-DosBoxXCommand -Command $DosBoxXCommand

    $hasWrestool = $null -ne (Get-Command wrestool -ErrorAction SilentlyContinue)
    $hasMagick = $null -ne (Get-Command magick -ErrorAction SilentlyContinue)
    if (-not $hasWrestool) {
        Write-Warning "wrestool was not found (install icoutils); only .ICO files can be extracted from the images."
    }
    if (-not $hasMagick) {
        Write-Warning "ImageMagick 7's 'magick' command was not found; an icon cannot be generated."
        return
    }

    function Test-IconFile {
        param([Parameter(Mandatory = $true)][string]$Path)
        if (-not (Test-Path -LiteralPath $Path)) { return $false }
        $null = & magick identify -format '%m %wx%h' $Path 2>$null
        return ($LASTEXITCODE -eq 0)
    }

    $iconPath = [System.IO.Path]::Join($programDir, "icon.png")
    if ((Test-Path -Path $iconPath) -and -not $Force) {
        Write-Host "Found icon at '$iconPath'."
        return
    }

    $searchImgs = @(
        (Get-ChildItem -Path $programDir | Where-Object { $_.Extension -in @('.iso', '.img', '.cue') } | ForEach-Object { $_.FullName }),
        "$programDir/hdd.vhd"
    ) | Where-Object { Test-Path -LiteralPath $_ }

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
        $allIcons = @(
            Get-ChildItem -Path $mountPoint -Recurse -Include '*.ICO', '*.ico' |
                Where-Object { $_.FullName -notlike "*windows*" -and $_.FullName -notlike "*win98*" } |
                Where-Object { Test-IconFile $_.FullName } |
                Sort-Object { $_.Name }
        )
        if ($allIcons.Count -eq 0) {
            Write-Host "No usable icons found in '$img'."
            continue
        }
        Write-Host @"
Choose which icon to use:
0) None of these
"@
        for ($i = 1; $i -le $allIcons.Count; $i++) {
            $icon = $allIcons[$i - 1]
            $iconName = $icon.FullName
            Write-Host "$i) $iconName"
        }
        $iconChoice = [int](Read-Host "Enter the number of the icon to use (0-$($allIcons.Count))")
        if ($iconChoice -eq 0) {
            break
        }
        if ($iconChoice -lt 1 -or $iconChoice -gt $allIcons.Count) {
            Write-Warning "Invalid icon number; skipping '$img'."
            continue
        }
        $iconFile = $allIcons[$iconChoice - 1].FullName
        $outputFile = "$programDir/icon.png"
        $size = 256
        & magick $iconFile -background none -filter Point -resize "x$size" -gravity center -crop "${size}x${size}+0+0" +repage -flatten -colors 256 $outputFile
        if ($LASTEXITCODE -eq 0 -and (Test-IconFile $outputFile)) {
            break
        }
        Write-Warning "Could not convert '$iconFile' to a usable icon."
        Remove-Item -Path $outputFile -Force -ErrorAction SilentlyContinue
    }
}
