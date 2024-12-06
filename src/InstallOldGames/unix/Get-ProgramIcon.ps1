function Get-ProgramIcon {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProgramDirName,

        [Parameter(Mandatory = $false)]
        [switch]$Force
    )

    $root = Get-OldGamesRoot
    $programDir = [System.IO.Path]::Join($root, "programs", $ProgramDirName)

    if (-not (Test-Path -Path $programDir)) {
        throw "Program directory '$programDir' does not exist."
    }

    $iconPath = [System.IO.Path]::Join($programDir, "icon.png")
    if ((Test-Path -Path $iconPath) -and -not $Force) {
        Write-Host "Found icon at '$iconPath'."
        return
    }

    $searchImgs = @((Get-ChildItem -Path $programDir | Where-Object { $_.Extension -in @('.iso', '.img', '.cue') } | ForEach-Object { $_.FullName }), "$programDir/hdd.vhd") | ForEach-Object { $_ }
    foreach ($img in $searchImgs) {
        Write-Host "Searching for icons in '$($img)'..."
        $mountPoint = "/tmp/oldgamesmnt"
        $iconDir = "$mountPoint/icons"
        rm -rf $mountPoint/*
        mkdir -p $mountPoint/icons/
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
        Write-Host "Running 'dosbox-x $pargs'..."
        Start-Process -FilePath "dosbox-x" -ArgumentList $pargs -Wait
        $exeFiles = Get-ChildItem -Path $mountPoint -Recurse -Include "*.EXE", "*.exe" | Where-Object { $_.FullName -notlike "*windows*" -and $_.FullName -notlike "*win98*" }
        $exeFiles | ForEach-Object {
            $exe = $_
            $icons = wrestool -l $exe.FullName --type=14 | ForEach-Object { [System.Text.RegularExpressions.Regex]::Match($_, "--name=([^ ]*)").Groups[1].Value }
            foreach ($icon in $icons) {
                $target = "$iconDir/$($exe.Name).$icon.ico"
                wrestool -x $exe.FullName --type=14 --name=$icon > $target
                if (-not (Get-Item $target).Length) {
                    Remove-Item $target
                }
            }
            $target = "$iconDir/$($exe.Name).ico"
            wrestool -x $exe.FullName > $target
            if (-not (Get-Item $target).Length) {
                Remove-Item $target
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
            convert -resize x${size} -gravity center -crop ${size}x${size}+0+0 "$iconFile" -flatten -colors 256 -background transparent "$outputFile"
            break
        }
    }
}