function Get-DosBoxXCommand {
    [CmdletBinding()]
    param(
        # Command used to launch DOSBox-X. The first element is the executable
        # (a path or a command on PATH); any remaining elements are passed to
        # it before the generated arguments. For a Flatpak install, use
        # @('flatpak', 'run', 'com.dosbox_x.DOSBox-X').
        #
        # When omitted, the OLDGAMES_DOSBOX_X environment variable is used if
        # set (e.g. "flatpak run com.dosbox_x.DOSBox-X"), otherwise
        # 'dosbox-x' is looked up on PATH.
        [Parameter()]
        [string[]]$Command
    )

    if (-not $Command -or $Command.Count -eq 0) {
        if ($env:OLDGAMES_DOSBOX_X) {
            $Command = $env:OLDGAMES_DOSBOX_X -split '\s+'
        } else {
            $Command = @('dosbox-x')
        }
    }

    # Allow the whole command to be passed as a single string, e.g.
    # 'flatpak run com.dosbox_x.DOSBox-X'. A quoted path containing spaces is
    # kept as one element as long as it exists.
    if ($Command.Count -eq 1) {
        $single = $Command[0].Trim().Trim('"')
        if ($single -match '\s' -and -not (Test-Path -LiteralPath $single)) {
            $Command = $single -split '\s+'
        } else {
            $Command = @($single)
        }
    }

    $exe = $Command[0]
    if (Test-Path -LiteralPath $exe) {
        $exe = (Resolve-Path -LiteralPath $exe).Path
    } else {
        $resolved = Get-Command -Name $exe -CommandType Application -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if (-not $resolved) {
            throw "DOSBox-X was not found: '$exe' is neither a path nor a command on PATH. " +
                "Install DOSBox-X, or pass -DosBoxXCommand (for a Flatpak install, " +
                "e.g. -DosBoxXCommand 'flatpak run com.dosbox_x.DOSBox-X')."
        }
        $exe = $resolved.Source
    }

    $arguments = @()
    if ($Command.Count -gt 1) {
        $arguments = $Command[1..($Command.Count - 1)]
    }

    Write-Output @{
        FilePath  = $exe
        Arguments = $arguments
    }
}
