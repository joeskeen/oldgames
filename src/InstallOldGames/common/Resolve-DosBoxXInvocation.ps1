function Resolve-DosBoxXInvocation {
    [CmdletBinding()]
    param(
        # The command returned by Get-DosBoxXCommand.
        [Parameter(Mandatory = $true)]
        [hashtable]$Command,

        # Directory DOSBox-X should treat as its working directory. This matters
        # because DOSBox-X resets its working directory to the user's home
        # directory (or a configured default) at startup, which breaks the
        # relative paths in the generated autoexec sections - especially when
        # DOSBox-X is launched through Flatpak.
        [Parameter()]
        [string]$WorkingDirectory,

        # Arguments for DOSBox-X itself.
        [Parameter()]
        [string[]]$Arguments = @()
    )

    $defaultDirArgs = @()
    if ($WorkingDirectory) {
        $defaultDirArgs = @('-defaultdir', "`"$WorkingDirectory`"")
    }

    $commandArgs = @($Command.Arguments | Where-Object { $null -ne $_ })

    Write-Output @{
        FilePath     = $Command.FilePath
        ArgumentList = $commandArgs + $defaultDirArgs + @($Arguments)
    }
}
