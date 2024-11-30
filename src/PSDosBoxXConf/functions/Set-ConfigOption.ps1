function Set-ConfigOption {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SectionName,

        [Parameter()]
        [string]$OptionName = $null,

        [Parameter()]
        [string]$Value = $null,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [System.Collections.Specialized.OrderedDictionary]$Config
    )

    if (-not $OptionName) {
        $Config[$SectionName] = $Value.Trim()
    } elseif ($null -ne $Config[$SectionName]) {
        $Config[$SectionName][$OptionName] = $Value
    } else {
        $Config[$SectionName] = [ordered]@{
            $OptionName = $Value
        }
    }

    Write-Output $Config
}
