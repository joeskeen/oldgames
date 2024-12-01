function Get-ProgramIcon {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProgramDirName
    )

    $root = Get-OldGamesRoot
    $programDir = [System.IO.Path]::Join($root, "programs", $ProgramDirName)

    if (-not (Test-Path -Path $programDir)) {
        throw "Program directory '$programDir' does not exist."
    }

    $iconPath = [System.IO.Path]::Join($programDir, "icon.png")
    if ((Test-Path -Path $iconPath)) {
        Write-Host "Found icon at '$iconPath'."
        return
    }

    $searchImgs = @((Get-ChildItem -Path $programDir | Where-Object { $_.Extension -in @('.iso', '.img', '.cue') }), "$programDir/hdd.vhd") | ForEach-Object {$_}
    foreach($img in $searchImgs) {
        Write-Host "Searching for icons in '$($img.FullName)'..."
        $mountPoint = "/tmp/oldgamesmnt"
        rm -rf $mountPoint/*
        mkdir -p $mountPoint/icons/
        $commands = @" 
            imgmount c "$($img.FullName)"
            mount d "$mountPoint" -nocachedir
            XCOPY C:\*.ICO D:\ /S /Y
            XCOPY C:\*.EXE D:\ /S /Y
"@ -split [System.Environment]::NewLine  | ForEach-Object { "-c `"$($_.Trim().Replace('"', '\"'))`"" }
        $pargs = "-silent $($commands -join ' ')"
        Write-Host "Running 'dosbox-x $pargs'..."
        Start-Process -FilePath "dosbox-x" -ArgumentList $pargs -Wait
        $iconFiles = Get-ChildItem -Path $mountPoint -Recurse -Include "*.ICO", "*.ico" | Where-Object { $_.FullName -notmatch "WINDOWS" }
        $exeFiles = Get-ChildItem -Path $mountPoint -Recurse -Include "*.EXE", "*.exe" | Where-Object { $_.FullName -notmatch "WINDOWS" }
        $exeFiles | ForEach-Object {
            $exe = $_
            wrestool -x $exe.FullName > "$mountPoint/icons/$($exe.Name).ico"
        }
        $allIcons = Get-ChildItem -Path $mountPoint -Recurse -Include '*.ICO','*.ico' | Sort-Object {$_.Name}
        Write-Host @"
Choose which icon to use:
0) None of these
"@
        for($i = 1; $i -le $allIcons.Length; $i++) {
            $icon = $allIcons[$i-1]
            $iconName = $icon.FullName
            Write-Host "$i) $iconName"
        }
        $iconChoice = Read-Host "Enter the number of the icon to use (0-$($allIcons.Length))"
        if ($iconChoice -ne 0) {
            $iconFile = $allIcons[$iconChoice - 1].FullName
            $outputFile = "$programDir/icon.png"
            $size = 256
            convert -resize x${size} -gravity center -crop ${size}x${size}+0+0 "$iconFile" -flatten -colors 256 -background transparent "$outputFile"
            break
        }
    }
}