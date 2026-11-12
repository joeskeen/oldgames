function Import-DiskImage {
    [CmdletBinding()]
    param(
        # The image to copy into a program directory: an ISO, a cue sheet, or
        # any other file that DOSBox-X can mount.
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$DestinationDir
    )

    $srcDir = Split-Path -Parent -Path $Path
    $fileName = Split-Path -Leaf -Path $Path
    $dst = Join-Path $DestinationDir $fileName
    Copy-Item -Path $Path -Destination $dst -Force

    if ($fileName -match '(?i)\.cue$') {
        # A cue sheet can reference one file or many (multi-track discs). Copy
        # every referenced file next to the cue and rewrite the references to
        # their bare file names so the whole set is self-contained.
        $lines = Get-Content -Path $Path
        $rewritten = foreach ($line in $lines) {
            $match = [regex]::Match($line, '^\s*FILE\s+"(?<file>[^"]+)"\s+BINARY', 'IgnoreCase')
            if (-not $match.Success) {
                $line
                continue
            }

            $referenced = $match.Groups['file'].Value
            $source = Join-Path $srcDir $referenced
            if (-not (Test-Path -LiteralPath $source)) {
                throw "The cue sheet '$fileName' references '$referenced', which was not found next to the cue."
            }

            $leafName = Split-Path -Leaf $referenced
            Copy-Item -Path $source -Destination (Join-Path $DestinationDir $leafName) -Force
            'FILE "' + $leafName + '" BINARY'
        }
        $rewritten | Set-Content -Path $dst
    }

    Write-Output $fileName
}
