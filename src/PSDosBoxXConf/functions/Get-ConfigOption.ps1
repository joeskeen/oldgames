function Get-ConfigOption {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SectionName,

        [Parameter()]
        [string]$OptionName,

        [Parameter(Mandatory = $true, ValueFromPipeline)]
        [System.Collections.Specialized.OrderedDictionary]$Config
    )

    if ($null -eq $OptionName) {
        Write-Output $Config[$SectionName]
    } elseif ($null -ne $Config[$SectionName]) {
        Write-Output $Config[$SectionName][$OptionName]
    } else {
        Write-Output $null
    }
}
