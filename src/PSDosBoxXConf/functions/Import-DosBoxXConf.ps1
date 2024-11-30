function Import-DosBoxXConf {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Path
    )

    if (-not (Test-Path -Path $Path)) {
        Write-Error "The path '$Path' does not exist."
        return
    }

    $configLines = (Get-Content -Path $Path -Raw) -split [Environment]::NewLine
    | Where-Object { -not ($_.StartsWith("# ")) }
    | ForEach-Object { $_ -replace '\r\n', "`n" } 
    | ForEach-Object { $_ -replace '\r', "`n" }
    | ForEach-Object { $_ -replace '\s+', " " }
    | ForEach-Object { $_.Trim() }
    | Where-Object { $_ -ne "" }

    $config = [ordered]@{}
    $currentSectionName = ""
    $currentSection = $null

    foreach ($line in $configLines) {
        if ($line -match "\[.*\]") {
            $currentSectionName = $line.TrimStart("[").TrimEnd("]")
            if ($currentSectionName -eq 'autoexec') {
                $currentSection = @('')
            } else {
                $currentSection = [ordered]@{}
            }
            $config[$currentSectionName] = $currentSection
        } elseif ($currentSectionName -ne 'autoexec') {
            $parts = $line.Split("=") | ForEach-Object { $_.Trim() }
            $key = $parts[0]
            $value = $parts[1]
            $currentSection[$key] = $value
        } else {
            $currentSection = @($currentSection, $line) | ForEach-Object { $_ }
            $config[$currentSectionName] = $currentSection
        }
    }

    Write-Output $config
}