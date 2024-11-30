$funcDir = "$PSScriptRoot/functions"
$funcFiles = Get-ChildItem -Path $funcDir -Recurse -Filter "*.ps1"
foreach ($funcFile in $funcFiles) {
    . $funcFile.FullName
    Export-ModuleMember -Function $funcFile.BaseName
}
