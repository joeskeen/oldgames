BeforeAll {
    Import-Module "$PSScriptRoot/../src/InstallOldGames" -Force
}

Describe 'Import-DiskImage' {
    BeforeEach {
        $script:source = Join-Path $TestDrive 'source'
        $script:dest = Join-Path $TestDrive 'dest'
        New-Item -ItemType Directory -Force $script:source, $script:dest | Out-Null
    }

    It 'copies a multi-track cue sheet and all referenced tracks' {
        @(
            'FILE "track01.bin" BINARY'
            '  TRACK 01 MODE1/2352'
            '    INDEX 01 00:00:00'
            'FILE "track02.bin" BINARY'
            '  TRACK 02 AUDIO'
            '    INDEX 01 00:00:00'
            'FILE "track03.bin" BINARY'
            '  TRACK 03 AUDIO'
            '    INDEX 01 00:00:00'
        ) | Set-Content (Join-Path $source 'game.cue')
        'data' | Set-Content (Join-Path $source 'track01.bin')
        'audio2' | Set-Content (Join-Path $source 'track02.bin')
        'audio3' | Set-Content (Join-Path $source 'track03.bin')

        $name = Import-DiskImage -Path (Join-Path $source 'game.cue') -DestinationDir $dest

        $name | Should -Be 'game.cue'
        foreach ($f in 'game.cue', 'track01.bin', 'track02.bin', 'track03.bin') {
            Test-Path (Join-Path $dest $f) | Should -BeTrue
        }
        (Get-Content (Join-Path $dest 'game.cue') -Raw).Contains('FILE "track01.bin" BINARY') | Should -BeTrue
        (Get-Content (Join-Path $dest 'game.cue') -Raw).Contains('FILE "track03.bin" BINARY') | Should -BeTrue
    }

    It 'flattens track references that use a subdirectory' {
        New-Item -ItemType Directory -Force (Join-Path $source 'tracks') | Out-Null
        @(
            'FILE "tracks/disc.bin" BINARY'
            '  TRACK 01 MODE1/2352'
        ) | Set-Content (Join-Path $source 'game.cue')
        'data' | Set-Content (Join-Path $source 'tracks/disc.bin')

        Import-DiskImage -Path (Join-Path $source 'game.cue') -DestinationDir $dest | Out-Null

        Test-Path (Join-Path $dest 'disc.bin') | Should -BeTrue
        (Get-Content (Join-Path $dest 'game.cue') -Raw).Contains('FILE "disc.bin" BINARY') | Should -BeTrue
    }

    It 'throws when a referenced track is missing' {
        @(
            'FILE "missing.bin" BINARY'
            '  TRACK 01 MODE1/2352'
        ) | Set-Content (Join-Path $source 'game.cue')

        { Import-DiskImage -Path (Join-Path $source 'game.cue') -DestinationDir $dest } |
            Should -Throw -ExpectedMessage '*missing.bin*'
    }

    It 'copies a plain ISO' {
        'iso' | Set-Content (Join-Path $source 'game.iso')
        Import-DiskImage -Path (Join-Path $source 'game.iso') -DestinationDir $dest | Out-Null
        Test-Path (Join-Path $dest 'game.iso') | Should -BeTrue
    }
}
