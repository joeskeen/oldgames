function Get-OldGamesRoot {
    param()

    $root = [System.IO.Path]::Join($PSScriptRoot, '../../..')
    Write-Output (Resolve-Path $root).Path
}