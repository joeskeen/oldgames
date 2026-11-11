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

    # DOSBox-X only treats lines that *start* with '#' as comments, but the
    # configuration files in this repository also use trailing comments
    # (e.g. 'core=dynamic_x86 # use after installed'). Strip the trailing
    # comments here so they do not become part of the option value when the
    # configuration is written back out.
    $configLines = (Get-Content -Path $Path -Raw) -split '\r\n|\n|\r' |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -ne '' -and -not $_.StartsWith('#') }

    $config = [ordered]@{}
    $currentSectionName = ""
    $currentSection = $null

    foreach ($line in $configLines) {
        if ($line -match '^\[(?<section>[^\]]+)\]') {
            # Anchor the section name to the start of the line so that values
            # containing brackets (e.g. a path like C:\games\[test].map) are
            # not mistaken for section headers.
            $currentSectionName = $Matches['section'].Trim()
            if ($currentSectionName -eq 'autoexec') {
                $currentSection = @('')
            } else {
                $currentSection = [ordered]@{}
            }
            $config[$currentSectionName] = $currentSection
        } elseif ($currentSectionName -eq 'autoexec') {
            # Lines in [autoexec] are commands, not key/value pairs, so keep
            # them verbatim.
            $currentSection = @($currentSection, $line) | ForEach-Object { $_ }
            $config[$currentSectionName] = $currentSection
        } else {
            # Only a comment preceded by whitespace is treated as trailing so
            # that a '#' inside a value (e.g. a path) is preserved.
            $line = $line -replace '\s+#.*$', ''
            # Split on the first '=' only; values may legitimately contain '='.
            $parts = $line -split '=', 2 | ForEach-Object { $_.Trim() }
            $key = $parts[0]
            $value = if ($parts.Count -gt 1) { $parts[1] } else { '' }
            $currentSection[$key] = $value
        }
    }

    Write-Output $config
}
