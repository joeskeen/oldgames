BeforeAll {
    Import-Module "$PSScriptRoot/../src/PSDosBoxXConf" -Force
}

Describe 'PSDosBoxXConf' {
    BeforeEach {
        $script:confPath = Join-Path $TestDrive 'dosbox-x.conf'
        @'
[sdl]
fullscreen = false
mapperfile = C:\games\[test].map

[cpu]
cputype = pentium_mmx
core = dynamic_x86 # this is a trailing comment

[autoexec]
# this is a full-line comment
imgmount c hdd.vhd
BOOT C:
'@ | Set-Content -Path $script:confPath
    }

    It 'keeps trailing inline comments out of option values' {
        $conf = Import-DosBoxXConf -Path $script:confPath
        $conf | Get-ConfigOption -SectionName 'cpu' -OptionName 'core' | Should -Be 'dynamic_x86'
    }

    It 'does not mistake a value containing brackets for a section header' {
        $conf = Import-DosBoxXConf -Path $script:confPath
        $conf | Get-ConfigOption -SectionName 'sdl' -OptionName 'mapperfile' | Should -Be 'C:\games\[test].map'
        $conf.Keys | Should -Not -Contain 'test'
    }

    It 'ignores full-line comments, including inside [autoexec]' {
        $conf = Import-DosBoxXConf -Path $script:confPath
        $autoexec = $conf | Get-ConfigOption -SectionName 'autoexec'
        $autoexec | Should -Contain 'imgmount c hdd.vhd'
        $autoexec | Should -Contain 'BOOT C:'
        ($autoexec -join "`n") | Should -Not -Match 'full-line comment'
    }

    It 'preserves values through an export/import round-trip' {
        $outPath = Join-Path $TestDrive 'out.conf'
        Import-DosBoxXConf -Path $script:confPath | Export-DosBoxXConf -Path $outPath

        $conf = Import-DosBoxXConf -Path $outPath
        $conf | Get-ConfigOption -SectionName 'sdl' -OptionName 'fullscreen' | Should -Be 'false'
        $conf | Get-ConfigOption -SectionName 'cpu' -OptionName 'core' | Should -Be 'dynamic_x86'
        $conf | Get-ConfigOption -SectionName 'sdl' -OptionName 'mapperfile' | Should -Be 'C:\games\[test].map'
        $conf | Get-ConfigOption -SectionName 'autoexec' | Should -Contain 'imgmount c hdd.vhd'
    }

    It 'adds a new option to an existing section' {
        $conf = Import-DosBoxXConf -Path $script:confPath
        $updated = $conf | Set-ConfigOption -SectionName 'cpu' -OptionName 'cycles' -Value 'max'
        $updated | Get-ConfigOption -SectionName 'cpu' -OptionName 'cycles' | Should -Be 'max'
    }
}
