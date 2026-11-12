BeforeAll {
    Import-Module "$PSScriptRoot/../src/InstallOldGames" -Force
}

Describe 'Get-OldGamesConfig' {
    BeforeEach {
        Remove-Item Env:OLDGAMES_USER_DATA_ROOT -ErrorAction SilentlyContinue
        $script:systemConfig = [System.IO.Path]::Join($TestDrive, 'etc', 'oldgames', 'config.json')
        $script:userConfig = [System.IO.Path]::Join($TestDrive, 'user', 'config.json')
        $script:missingSystem = [System.IO.Path]::Join($TestDrive, 'missing-system.json')
        $script:missingUser = [System.IO.Path]::Join($TestDrive, 'missing-user.json')
        New-Item -Path (Split-Path -Parent $script:systemConfig) -ItemType Directory -Force | Out-Null
        New-Item -Path (Split-Path -Parent $script:userConfig) -ItemType Directory -Force | Out-Null
    }

    AfterEach {
        Remove-Item Env:OLDGAMES_USER_DATA_ROOT -ErrorAction SilentlyContinue
    }

    It 'uses the per-user default when no configuration exists' {
        $config = Get-OldGamesConfig `
            -SystemConfigPath $script:missingSystem `
            -UserConfigPath $script:missingUser `
            -UserName 'alice'

        $config.UserDataRoot | Should -Be ([System.IO.Path]::Join($HOME, '.config', 'oldgames'))
        $config.IsDefault | Should -BeTrue
        $config.Sources.Count | Should -Be 0
    }

    It 'expands {user} from the system configuration' {
        Set-Content -LiteralPath $script:systemConfig -Value '{"userDataRoot":"/mnt/nas/{user}/.oldgames"}'

        $config = Get-OldGamesConfig `
            -SystemConfigPath $script:systemConfig `
            -UserConfigPath $script:missingUser `
            -UserName 'bob'

        $config.UserDataRoot | Should -Be '/mnt/nas/bob/.oldgames'
        $config.IsDefault | Should -BeFalse
        $config.Sources['UserDataRoot'] | Should -Be $script:systemConfig
    }

    It 'lets the per-user configuration override the system configuration' {
        Set-Content -LiteralPath $script:systemConfig -Value '{"userDataRoot":"/mnt/system/{user}/.oldgames"}'
        Set-Content -LiteralPath $script:userConfig -Value '{"userDataRoot":"/mnt/user/{user}/.oldgames"}'

        $config = Get-OldGamesConfig `
            -SystemConfigPath $script:systemConfig `
            -UserConfigPath $script:userConfig `
            -UserName 'alice'

        $config.UserDataRoot | Should -Be '/mnt/user/alice/.oldgames'
        $config.Sources['UserDataRoot'] | Should -Be $script:userConfig
    }

    It 'lets the environment variable override the per-user configuration' {
        Set-Content -LiteralPath $script:userConfig -Value '{"userDataRoot":"/mnt/user/{user}/.oldgames"}'
        $env:OLDGAMES_USER_DATA_ROOT = '/mnt/env/{user}/.oldgames'

        $config = Get-OldGamesConfig `
            -SystemConfigPath $script:missingSystem `
            -UserConfigPath $script:userConfig `
            -UserName 'alice'

        $config.UserDataRoot | Should -Be '/mnt/env/alice/.oldgames'
        $config.Sources['UserDataRoot'] | Should -Be 'OLDGAMES_USER_DATA_ROOT'
    }

    It 'lets -UserDataRoot override everything else' {
        $env:OLDGAMES_USER_DATA_ROOT = '/mnt/env/{user}/.oldgames'

        $config = Get-OldGamesConfig `
            -SystemConfigPath $script:missingSystem `
            -UserConfigPath $script:missingUser `
            -UserName 'alice' `
            -UserDataRoot '/mnt/parameter/{user}/.oldgames'

        $config.UserDataRoot | Should -Be '/mnt/parameter/alice/.oldgames'
        $config.Sources['UserDataRoot'] | Should -Be '-UserDataRoot'
    }

    It 'expands a leading ~' {
        Set-Content -LiteralPath $script:userConfig -Value '{"userDataRoot":"~/saves/{user}"}'

        $config = Get-OldGamesConfig `
            -SystemConfigPath $script:missingSystem `
            -UserConfigPath $script:userConfig `
            -UserName 'alice'

        $config.UserDataRoot | Should -Be ([System.IO.Path]::Join($HOME, 'saves', 'alice'))
    }

    It 'rejects a relative data root' {
        Set-Content -LiteralPath $script:systemConfig -Value '{"userDataRoot":"relative/path"}'

        {
            Get-OldGamesConfig `
                -SystemConfigPath $script:systemConfig `
                -UserConfigPath $script:missingUser `
                -UserName 'alice'
        } | Should -Throw '*absolute path*'
    }

    It 'reports malformed JSON with the file name' {
        Set-Content -LiteralPath $script:systemConfig -Value 'not json'

        {
            Get-OldGamesConfig `
                -SystemConfigPath $script:systemConfig `
                -UserConfigPath $script:missingUser `
                -UserName 'alice'
        } | Should -Throw "*$($script:systemConfig)*"
    }
}
