BeforeAll {
    Import-Module "$PSScriptRoot/../src/InstallOldGames" -Force

    function Write-TestBe32 {
        param([byte[]]$Bytes, [int]$Offset, [uint32]$Value)
        $Bytes[$Offset] = [byte](($Value -shr 24) -band 0xFF)
        $Bytes[$Offset + 1] = [byte](($Value -shr 16) -band 0xFF)
        $Bytes[$Offset + 2] = [byte](($Value -shr 8) -band 0xFF)
        $Bytes[$Offset + 3] = [byte]($Value -band 0xFF)
    }

    function Write-TestBe64 {
        param([byte[]]$Bytes, [int]$Offset, [uint64]$Value)
        for ($i = 7; $i -ge 0; $i--) {
            $Bytes[$Offset + (7 - $i)] = [byte](($Value -shr (8 * $i)) -band 0xFF)
        }
    }

    function Read-TestBe32 {
        param([byte[]]$Bytes, [int]$Offset)
        return ([uint32]$Bytes[$Offset] -shl 24) -bor
            ([uint32]$Bytes[$Offset + 1] -shl 16) -bor
            ([uint32]$Bytes[$Offset + 2] -shl 8) -bor
            [uint32]$Bytes[$Offset + 3]
    }

    function Set-TestHeaderChecksum {
        param([byte[]]$Bytes, [int]$HeaderOffset)
        Write-TestBe32 -Bytes $Bytes -Offset ($HeaderOffset + 36) -Value 0
        [uint64]$sum = 0
        for ($i = 0; $i -lt 1024; $i++) {
            $sum += $Bytes[$HeaderOffset + $i]
        }
        $checksum = [uint32](-bnot ([uint32]($sum -band [uint64]::MaxValue)))
        Write-TestBe32 -Bytes $Bytes -Offset ($HeaderOffset + 36) -Value $checksum
    }

    function New-TestDifferencingVhd {
        param(
            [string]$Path,
            [string]$AbsoluteParent,
            [string]$RelativeParent
        )

        $bytes = New-Object byte[] 8192
        $ascii = [System.Text.Encoding]::ASCII

        # Footer at offset 0.
        [Array]::Copy($ascii.GetBytes('conectix'), 0, $bytes, 0, 8)
        Write-TestBe64 -Bytes $bytes -Offset 16 -Value 512   # dataOffset
        Write-TestBe32 -Bytes $bytes -Offset 60 -Value 4     # differencing

        # Dynamic header at offset 512.
        $header = 512
        [Array]::Copy($ascii.GetBytes('cxsparse'), 0, $bytes, $header, 8)
        Write-TestBe32 -Bytes $bytes -Offset ($header + 32) -Value (2 * 1024 * 1024) # blockSize

        foreach ($entry in @(
            @{ Index = 0; Code = [uint32]0x57326B75; Value = $AbsoluteParent; Offset = 2048 },
            @{ Index = 1; Code = [uint32]0x57327275; Value = $RelativeParent; Offset = 2560 }
        )) {
            $entryOffset = $header + 576 + ($entry.Index * 24)
            Write-TestBe32 -Bytes $bytes -Offset $entryOffset -Value $entry.Code
            Write-TestBe32 -Bytes $bytes -Offset ($entryOffset + 4) -Value 512
            $stringBytes = [System.Text.Encoding]::Unicode.GetBytes($entry.Value)
            Write-TestBe32 -Bytes $bytes -Offset ($entryOffset + 8) -Value ([uint32]$stringBytes.Length)
            Write-TestBe64 -Bytes $bytes -Offset ($entryOffset + 16) -Value ([uint64]$entry.Offset)
            [Array]::Copy($stringBytes, 0, $bytes, $entry.Offset, $stringBytes.Length)
        }

        Set-TestHeaderChecksum -Bytes $bytes -HeaderOffset $header
        [System.IO.File]::WriteAllBytes($Path, $bytes)
    }
}

Describe 'Update-VhdParentPath' {
    BeforeEach {
        $script:programsRoot = [System.IO.Path]::Join($TestDrive, 'programs', 'doom')
        New-Item -Path $script:programsRoot -ItemType Directory -Force | Out-Null
        $script:parent = [System.IO.Path]::Join($script:programsRoot, 'hdd.vhd')
        Set-Content -LiteralPath $script:parent -Value 'parent placeholder'

        $script:childDir = [System.IO.Path]::Join($TestDrive, 'users', 'alice', '.oldgames', 'programs', 'doom')
        New-Item -Path $script:childDir -ItemType Directory -Force | Out-Null
        $script:child = [System.IO.Path]::Join($script:childDir, 'hdd.vhd')

        New-TestDifferencingVhd `
            -Path $script:child `
            -AbsoluteParent '\old\location\programs\doom\hdd.vhd' `
            -RelativeParent '..\..\old\location\programs\doom\hdd.vhd'
    }

    It 'rewrites both locators and keeps the header checksum valid' {
        $result = Update-VhdParentPath -ChildPath $script:child -ParentPath $script:parent -Confirm:$false

        $result.Updated | Should -BeTrue
        $expectedRelative = [System.IO.Path]::GetRelativePath($script:childDir, (Resolve-Path $script:parent).Path).Replace('/', '\')
        $result.RelativePath | Should -Be $expectedRelative

        $bytes = [System.IO.File]::ReadAllBytes($script:child)
        $absoluteLength = Read-TestBe32 -Bytes $bytes -Offset (512 + 576 + 8)
        $relativeLength = Read-TestBe32 -Bytes $bytes -Offset (512 + 600 + 8)

        [System.Text.Encoding]::Unicode.GetString($bytes, 2048, $absoluteLength) |
            Should -Be $result.AbsolutePath
        [System.Text.Encoding]::Unicode.GetString($bytes, 2560, $relativeLength) |
            Should -Be $expectedRelative

        $storedChecksum = Read-TestBe32 -Bytes $bytes -Offset (512 + 36)
        $checksumBytes = New-Object byte[] 1024
        [Array]::Copy($bytes, 512, $checksumBytes, 0, 1024)
        Write-TestBe32 -Bytes $checksumBytes -Offset 36 -Value 0
        [uint64]$sum = 0
        foreach ($byte in $checksumBytes) {
            $sum += $byte
        }
        $calculatedChecksum = [uint32](-bnot ([uint32]($sum -band [uint64]::MaxValue)))
        $storedChecksum | Should -Be $calculatedChecksum
    }

    It 'is idempotent' {
        $null = Update-VhdParentPath -ChildPath $script:child -ParentPath $script:parent -Confirm:$false
        $second = Update-VhdParentPath -ChildPath $script:child -ParentPath $script:parent -Confirm:$false

        $second.Updated | Should -BeFalse
    }

    It 'refuses a child whose header checksum is invalid' {
        $bytes = [System.IO.File]::ReadAllBytes($script:child)
        # Decimal form: PowerShell parses 0xDEADBEEF as a negative Int32.
        Write-TestBe32 -Bytes $bytes -Offset (512 + 36) -Value 3735928559
        [System.IO.File]::WriteAllBytes($script:child, $bytes)

        {
            Update-VhdParentPath -ChildPath $script:child -ParentPath $script:parent -Confirm:$false
        } | Should -Throw '*checksum*'
    }

    It 'refuses a VHD that is not a differencing disk' {
        $bytes = [System.IO.File]::ReadAllBytes($script:child)
        Write-TestBe32 -Bytes $bytes -Offset 60 -Value 3
        [System.IO.File]::WriteAllBytes($script:child, $bytes)

        {
            Update-VhdParentPath -ChildPath $script:child -ParentPath $script:parent -Confirm:$false
        } | Should -Throw '*not a differencing VHD*'
    }
}
