BeforeAll {
    Import-Module "$PSScriptRoot/../src/InstallOldGames" -Force
}

Describe 'Resolve-DosBoxXInvocation' {
    It 'adds -defaultdir for the working directory' {
        $command = @{ FilePath = '/usr/bin/dosbox-x'; Arguments = @() }
        $result = Resolve-DosBoxXInvocation -Command $command `
            -WorkingDirectory '/opt/games/doom' -Arguments @('-conf', 'dosbox-x.conf')

        $result.FilePath | Should -Be '/usr/bin/dosbox-x'
        ($result.ArgumentList -join '|') | Should -Be '-defaultdir|"/opt/games/doom"|-conf|dosbox-x.conf'
    }

    It 'keeps base command arguments (e.g. flatpak run) before the generated ones' {
        $command = @{ FilePath = '/usr/bin/flatpak'; Arguments = @('run', 'com.dosbox_x.DOSBox-X') }
        $result = Resolve-DosBoxXInvocation -Command $command `
            -WorkingDirectory '/opt/games/doom' -Arguments @('-conf', 'x.conf')

        ($result.ArgumentList -join '|') | Should -Be 'run|com.dosbox_x.DOSBox-X|-defaultdir|"/opt/games/doom"|-conf|x.conf'
    }

    It 'does not add -defaultdir when no working directory is given' {
        $command = @{ FilePath = '/usr/bin/dosbox-x'; Arguments = @() }
        $result = Resolve-DosBoxXInvocation -Command $command -Arguments @('-silent', '-c', 'exit')

        ($result.ArgumentList -join '|') | Should -Be '-silent|-c|exit'
    }

    It 'ignores null entries in the base command arguments' {
        $command = @{ FilePath = '/usr/bin/dosbox-x'; Arguments = @($null) }
        $result = Resolve-DosBoxXInvocation -Command $command -Arguments @('-conf', 'x.conf')

        ($result.ArgumentList -join '|') | Should -Be '-conf|x.conf'
    }
}
