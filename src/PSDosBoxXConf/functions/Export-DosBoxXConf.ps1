function Export-DosBoxXConf {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Path,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [System.Collections.Specialized.OrderedDictionary]
        $Config
    )

    $configLines = @('')
    foreach ($sectionName in $Config.Keys) {
        $section = $Config[$sectionName]
        $configLines += "[${sectionName}]"
        if ($sectionName -eq 'autoexec') {
            $configLines += $section
        } else {
            foreach ($key in $section.Keys) {
                $value = $section[$key]
                $configLines += "${key} = ${value}"
            }
        }
        $configLines += ''
    }

    ($configLines -join [System.Environment]::NewLine).Trim() | Set-Content -Path $Path
}
