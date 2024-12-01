$funcDir = switch ([System.Environment]::OSVersion.Platform) {
    Unix {
        "$PSScriptRoot/unix"
    }
}

if (-not $funcDir) {
    throw "Unsupported platform '$([System.Environment]::OSVersion.Platform)'."
    return
}

$funcFiles = Get-ChildItem -Path $funcDir -Recurse -Filter "*.ps1"
foreach ($funcFile in $funcFiles) {
    . $funcFile.FullName
    Export-ModuleMember -Function $funcFile.BaseName
}
