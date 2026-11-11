BeforeAll {
    Import-Module "$PSScriptRoot/../src/InstallOldGames" -Force
}

Describe 'Get-DosBoxXCommand' {
    AfterEach {
        Remove-Item Env:OLDGAMES_DOSBOX_X -ErrorAction SilentlyContinue
    }

    It 'resolves a command on PATH' {
        $result = Get-DosBoxXCommand -Command 'sh'
        $result.FilePath | Should -Not -BeNullOrEmpty
        (Split-Path -Leaf $result.FilePath) | Should -Be 'sh'
        $result.Arguments | Should -BeNullOrEmpty
    }

    It 'splits a single command string that contains arguments' {
        $result = Get-DosBoxXCommand -Command 'sh -c true'
        (Split-Path -Leaf $result.FilePath) | Should -Be 'sh'
        $result.Arguments | Should -Be @('-c', 'true')
    }

    It 'keeps an argument array intact' {
        $result = Get-DosBoxXCommand -Command @('sh', '-c', 'true')
        (Split-Path -Leaf $result.FilePath) | Should -Be 'sh'
        $result.Arguments | Should -Be @('-c', 'true')
    }

    It 'falls back to the OLDGAMES_DOSBOX_X environment variable' {
        $env:OLDGAMES_DOSBOX_X = 'sh -c true'
        $result = Get-DosBoxXCommand
        (Split-Path -Leaf $result.FilePath) | Should -Be 'sh'
        $result.Arguments | Should -Be @('-c', 'true')
    }

    It 'throws a helpful error when the command cannot be found' {
        { Get-DosBoxXCommand -Command 'definitely-not-a-real-command-xyz' } |
            Should -Throw -ExpectedMessage '*DOSBox-X was not found*'
    }
}
