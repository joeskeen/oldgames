function Get-OldGamesConfig {
    [CmdletBinding()]
    param(
        # Highest-priority override, exposed as -UserDataRoot on
        # Start-Program.ps1.
        [Parameter()]
        [string]$UserDataRoot,

        # Machine-wide configuration file. Kept as a parameter so the
        # precedence rules can be tested without touching /etc.
        [Parameter()]
        [string]$SystemConfigPath = '/etc/oldgames/config.json',

        # Per-user configuration file. Defaults to
        # $HOME/.config/oldgames/config.json.
        [Parameter()]
        [string]$UserConfigPath,

        # Name substituted for {user}. Defaults to the Linux login name.
        [Parameter()]
        [string]$UserName
    )

    if (-not $UserConfigPath) {
        $UserConfigPath = [System.IO.Path]::Join($HOME, '.config', 'oldgames', 'config.json')
    }

    if (-not $UserName) {
        $UserName = $env:USER
        if (-not $UserName) {
            $UserName = [Environment]::UserName
        }
        if (-not $UserName -and $HOME) {
            $UserName = Split-Path -Leaf $HOME
        }
    }
    if (-not $UserName) {
        throw "Could not determine the current user name. Set the USER environment variable or pass -UserName."
    }

    $settings = [ordered]@{
        UserDataRoot = [System.IO.Path]::Join($HOME, '.config', 'oldgames')
    }
    $sources = @{}
    $isDefault = $true

    function Get-SettingValue {
        param($Table, [string]$Name)

        if ($null -eq $Table) {
            return $null
        }
        foreach ($key in $Table.Keys) {
            # PowerShell's -eq is case-insensitive, so both 'userDataRoot'
            # and 'UserDataRoot' are accepted.
            if ([string]$key -eq $Name) {
                return $Table[$key]
            }
        }
        return $null
    }

    function Read-SettingsFile {
        param([string]$Path)

        if (-not (Test-Path -LiteralPath $Path)) {
            return $null
        }
        try {
            $text = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
        } catch {
            throw "Could not read the OldGames configuration '$Path': $($_.Exception.Message)"
        }
        if ([string]::IsNullOrWhiteSpace($text)) {
            return @{}
        }
        try {
            # -AsHashtable keeps unknown keys inspectable and avoids the
            # surprising property lookups of PSCustomObject.
            $data = $text | ConvertFrom-Json -AsHashtable -ErrorAction Stop
        } catch {
            throw "Could not parse the OldGames configuration '$Path' as JSON: $($_.Exception.Message)"
        }
        if ($data -isnot [System.Collections.IDictionary]) {
            throw "The OldGames configuration '$Path' must contain a JSON object."
        }
        foreach ($key in $data.Keys) {
            if ([string]$key -notin @('userDataRoot', '$schema')) {
                Write-Warning "Ignoring unknown OldGames configuration key '$key' in '$Path'."
            }
        }
        return $data
    }

    $systemData = Read-SettingsFile -Path $SystemConfigPath
    $systemRoot = Get-SettingValue -Table $systemData -Name 'userDataRoot'
    if ($null -ne $systemRoot -and "$systemRoot" -ne '') {
        if ($systemRoot -isnot [string]) {
            throw "The 'userDataRoot' value in '$SystemConfigPath' must be a string."
        }
        $settings.UserDataRoot = $systemRoot
        $sources['UserDataRoot'] = $SystemConfigPath
        $isDefault = $false
    }

    $userData = Read-SettingsFile -Path $UserConfigPath
    $userRoot = Get-SettingValue -Table $userData -Name 'userDataRoot'
    if ($null -ne $userRoot -and "$userRoot" -ne '') {
        if ($userRoot -isnot [string]) {
            throw "The 'userDataRoot' value in '$UserConfigPath' must be a string."
        }
        $settings.UserDataRoot = $userRoot
        $sources['UserDataRoot'] = $UserConfigPath
        $isDefault = $false
    }

    if ($env:OLDGAMES_USER_DATA_ROOT) {
        $settings.UserDataRoot = $env:OLDGAMES_USER_DATA_ROOT
        $sources['UserDataRoot'] = 'OLDGAMES_USER_DATA_ROOT'
        $isDefault = $false
    }

    if ($UserDataRoot) {
        $settings.UserDataRoot = $UserDataRoot
        $sources['UserDataRoot'] = '-UserDataRoot'
        $isDefault = $false
    }

    $root = [string]$settings.UserDataRoot
    if ([string]::IsNullOrWhiteSpace($root)) {
        throw "The user data root is empty. Set 'userDataRoot' in '$SystemConfigPath' or '$UserConfigPath'."
    }

    # Placeholders: {user} is the login name; ~ and $HOME are accepted for
    # convenience in hand-written configuration files.
    $root = $root.Replace('{user}', $UserName)
    $root = $root.Replace('$HOME', $HOME)
    if ($root -eq '~') {
        $root = $HOME
    } elseif ($root.StartsWith('~/')) {
        $root = [System.IO.Path]::Join($HOME, $root.Substring(2))
    }

    if (-not [System.IO.Path]::IsPathRooted($root)) {
        throw "The user data root '$root' must be an absolute path after expanding {user}."
    }
    $root = [System.IO.Path]::GetFullPath($root)

    [pscustomobject]@{
        UserDataRoot     = $root
        UserName         = $UserName
        UserConfigPath   = $UserConfigPath
        SystemConfigPath = $SystemConfigPath
        IsDefault        = $isDefault
        Sources          = $sources
    }
}
