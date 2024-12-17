function Get-ProgramFullName {
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

    $fullNamePath = [System.IO.Path]::Join($programDir, "program-name.txt")
    if ((Test-Path -Path $fullNamePath)) {
        $fullProgramName = Get-Content -Path $fullNamePath
    } else {
        Write-Host "Program name file not found for $ProgramDirName."
        $fullProgramName = Read-Host "Enter the full name of the program"
        $fullProgramName | Out-File -FilePath "$programDir/program-name.txt"
    }

    Write-Output $fullProgramName
}
