$commonFuncDir = "$PSScriptRoot/common"

$funcFiles = Get-ChildItem -Path $commonFuncDir -Recurse -Filter "*.ps1"
foreach ($funcFile in $funcFiles) {
    . $funcFile.FullName
    Export-ModuleMember -Function $funcFile.BaseName
}

# Platform-specific functions

$platformFuncDir = switch ([System.Environment]::OSVersion.Platform) {
    Unix {
        "$PSScriptRoot/unix"
    }
}

if (-not $platformFuncDir) {
    throw "Unsupported platform '$([System.Environment]::OSVersion.Platform)'."
    return
}

$funcFiles = Get-ChildItem -Path $platformFuncDir -Recurse -Filter "*.ps1"
foreach ($funcFile in $funcFiles) {
    . $funcFile.FullName
    Export-ModuleMember -Function $funcFile.BaseName
}
