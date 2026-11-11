function Start-DosBoxX {
    [CmdletBinding()]
    param(
        # The command returned by Get-DosBoxXCommand.
        [Parameter(Mandatory = $true)]
        [hashtable]$Command,

        # Directory DOSBox-X should treat as its working directory. Required
        # whenever the configuration uses relative paths (it almost always does).
        [Parameter()]
        [string]$WorkingDirectory,

        # Arguments for DOSBox-X itself.
        [Parameter()]
        [string[]]$Arguments = @(),

        [Parameter()]
        [switch]$Wait
    )

    $invocation = Resolve-DosBoxXInvocation `
        -Command $Command `
        -WorkingDirectory $WorkingDirectory `
        -Arguments $Arguments

    $startArguments = @{
        FilePath     = $invocation.FilePath
        ArgumentList = $invocation.ArgumentList
    }
    if ($WorkingDirectory) {
        $startArguments['WorkingDirectory'] = $WorkingDirectory
    }
    if ($Wait) {
        $startArguments['Wait'] = $true
    }

    Start-Process @startArguments
}
