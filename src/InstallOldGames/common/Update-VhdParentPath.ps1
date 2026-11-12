# Helpers for the big-endian integer fields in a VHD footer/header. The VHD
# format stores integers in network byte order, while the parent locator
# strings are UTF-16LE.
function Read-BigEndianUInt32 {
    param(
        [Parameter(Mandatory = $true)][byte[]]$Bytes,
        [Parameter(Mandatory = $true)][int]$Offset
    )
    return ([uint32]$Bytes[$Offset] -shl 24) -bor
        ([uint32]$Bytes[$Offset + 1] -shl 16) -bor
        ([uint32]$Bytes[$Offset + 2] -shl 8) -bor
        [uint32]$Bytes[$Offset + 3]
}

function Read-BigEndianUInt64 {
    param(
        [Parameter(Mandatory = $true)][byte[]]$Bytes,
        [Parameter(Mandatory = $true)][int]$Offset
    )
    [uint64]$value = 0
    for ($i = 0; $i -lt 8; $i++) {
        $value = ($value -shl 8) -bor $Bytes[$Offset + $i]
    }
    return $value
}

function Write-BigEndianUInt32 {
    param(
        [Parameter(Mandatory = $true)][byte[]]$Bytes,
        [Parameter(Mandatory = $true)][int]$Offset,
        [Parameter(Mandatory = $true)][uint32]$Value
    )
    $Bytes[$Offset] = [byte](($Value -shr 24) -band 0xFF)
    $Bytes[$Offset + 1] = [byte](($Value -shr 16) -band 0xFF)
    $Bytes[$Offset + 2] = [byte](($Value -shr 8) -band 0xFF)
    $Bytes[$Offset + 3] = [byte]($Value -band 0xFF)
}

function Read-ExactBuffer {
    param(
        [Parameter(Mandatory = $true)][System.IO.Stream]$Stream,
        [Parameter(Mandatory = $true)][int]$Count
    )
    $buffer = New-Object byte[] $Count
    $offset = 0
    while ($offset -lt $Count) {
        $read = $Stream.Read($buffer, $offset, $Count - $offset)
        if ($read -le 0) {
            throw "Unexpected end of file while reading '$($Stream.Name)'."
        }
        $offset += $read
    }
    return ,$buffer
}

function Update-VhdParentPath {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        # The differencing (child) VHD created for a user.
        [Parameter(Mandatory = $true)]
        [string]$ChildPath,

        # The game's install image, which is the child's parent.
        [Parameter(Mandatory = $true)]
        [string]$ParentPath
    )

    if (-not (Test-Path -LiteralPath $ChildPath -PathType Leaf)) {
        throw "The child VHD '$ChildPath' does not exist."
    }
    if (-not (Test-Path -LiteralPath $ParentPath -PathType Leaf)) {
        throw "The parent VHD '$ParentPath' does not exist."
    }

    $child = (Resolve-Path -LiteralPath $ChildPath).Path
    $parent = (Resolve-Path -LiteralPath $ParentPath).Path

    if (-not $PSCmdlet.ShouldProcess($child, "Repair the recorded parent path to '$parent'")) {
        return
    }

    $stream = [System.IO.File]::Open(
        $child,
        [System.IO.FileMode]::Open,
        [System.IO.FileAccess]::ReadWrite,
        [System.IO.FileShare]::None
    )
    try {
        $footer = Read-ExactBuffer -Stream $stream -Count 512
        if ([System.Text.Encoding]::ASCII.GetString($footer, 0, 8) -ne 'conectix') {
            throw "'$child' is not a VHD (missing the 'conectix' footer)."
        }

        # diskType at footer offset 60: 4 = differencing.
        $diskType = Read-BigEndianUInt32 -Bytes $footer -Offset 60
        if ($diskType -ne 4) {
            throw "'$child' is not a differencing VHD (disk type $diskType); there is no parent path to repair."
        }

        # dataOffset at footer offset 16 points at the 1024-byte dynamic header.
        [uint64]$dataOffset = Read-BigEndianUInt64 -Bytes $footer -Offset 16
        if ($dataOffset -lt 512 -or ($dataOffset + 1024) -gt [uint64]$stream.Length) {
            throw "The dynamic header offset in '$child' is invalid."
        }

        $stream.Position = [int64]$dataOffset
        $header = Read-ExactBuffer -Stream $stream -Count 1024
        if ([System.Text.Encoding]::ASCII.GetString($header, 0, 8) -ne 'cxsparse') {
            throw "The dynamic header of '$child' is invalid (missing 'cxsparse')."
        }

        # Validate the header checksum before changing anything. It is the
        # one's complement of the sum of the 1024 header bytes, with the
        # checksum field itself treated as zero.
        $storedChecksum = Read-BigEndianUInt32 -Bytes $header -Offset 36
        $checksumHeader = [byte[]]$header.Clone()
        Write-BigEndianUInt32 -Bytes $checksumHeader -Offset 36 -Value 0
        [uint64]$sum = 0
        foreach ($byte in $checksumHeader) {
            $sum += $byte
        }
        $calculatedChecksum = [uint32](-bnot ([uint32]($sum -band [uint64]::MaxValue)))
        if ($storedChecksum -ne $calculatedChecksum) {
            throw "The dynamic header of '$child' has an invalid checksum; refusing to modify it."
        }

        $childDir = Split-Path -Parent $child
        # DOSBox-X records the parent twice: an absolute path and a path
        # relative to the child. It tries the absolute one first, so both
        # need to be correct.
        $relativePath = [System.IO.Path]::GetRelativePath($childDir, $parent).Replace('/', '\')
        $absolutePath = $parent.Replace('/', '\')
        if (-not $absolutePath.StartsWith('\')) {
            $absolutePath = '\' + $absolutePath
        }

        $locators = @()
        $updated = $false

        for ($i = 0; $i -lt 8; $i++) {
            $entryOffset = 576 + ($i * 24)
            $platformCode = Read-BigEndianUInt32 -Bytes $header -Offset $entryOffset

            # Use if/elseif rather than switch: 'continue' inside a PowerShell
            # switch does not advance the enclosing for loop.
            if ($platformCode -eq 0x57326B75) {
                $newValue = $absolutePath # W2ku (absolute)
            } elseif ($platformCode -eq 0x57327275) {
                $newValue = $relativePath # W2ru (relative)
            } else {
                continue
            }

            $platformDataSpace = Read-BigEndianUInt32 -Bytes $header -Offset ($entryOffset + 4)
            $platformDataLength = Read-BigEndianUInt32 -Bytes $header -Offset ($entryOffset + 8)
            [uint64]$platformDataOffset = Read-BigEndianUInt64 -Bytes $header -Offset ($entryOffset + 16)

            if ($platformDataLength -gt $platformDataSpace) {
                throw "The parent locator in '$child' is corrupt (length $platformDataLength exceeds space $platformDataSpace)."
            }
            if ($platformDataOffset -eq 0 -or ($platformDataOffset + $platformDataSpace) -gt [uint64]$stream.Length) {
                throw "The parent locator in '$child' points outside the file."
            }

            $newBytes = [System.Text.Encoding]::Unicode.GetBytes($newValue)
            if ($newBytes.Length -gt $platformDataSpace) {
                throw "The new parent path '$newValue' does not fit in the locator space ($platformDataSpace bytes) of '$child'."
            }

            $stream.Position = [int64]$platformDataOffset
            $currentBytes = Read-ExactBuffer -Stream $stream -Count ([int]$platformDataLength)
            $currentValue = [System.Text.Encoding]::Unicode.GetString($currentBytes).TrimEnd([char]0)

            $locators += [pscustomobject]@{
                PlatformCode = ('0x{0:x8}' -f $platformCode)
                Current      = $currentValue
                New          = $newValue
            }

            if ($currentValue -eq $newValue -and $platformDataLength -eq $newBytes.Length) {
                continue
            }

            # Zero-fill the locator's full allocated space, then write the
            # new UTF-16LE string. The length field and the header checksum
            # are updated below.
            $block = New-Object byte[] ([int]$platformDataSpace)
            [Array]::Copy($newBytes, $block, $newBytes.Length)
            $stream.Position = [int64]$platformDataOffset
            $stream.Write($block, 0, [int]$platformDataSpace)
            Write-BigEndianUInt32 -Bytes $header -Offset ($entryOffset + 8) -Value ([uint32]$newBytes.Length)
            $updated = $true
        }

        if ($locators.Count -eq 0) {
            throw "The differencing VHD '$child' has no W2ku/W2ru parent locator to repair."
        }

        if ($updated) {
            Write-BigEndianUInt32 -Bytes $header -Offset 36 -Value 0
            [uint64]$sum = 0
            foreach ($byte in $header) {
                $sum += $byte
            }
            $checksum = [uint32](-bnot ([uint32]($sum -band [uint64]::MaxValue)))
            Write-BigEndianUInt32 -Bytes $header -Offset 36 -Value $checksum

            $stream.Position = [int64]$dataOffset
            $stream.Write($header, 0, 1024)
            $stream.Flush()
        }

        [pscustomobject]@{
            ChildPath    = $child
            ParentPath   = $parent
            RelativePath = $relativePath
            AbsolutePath = $absolutePath
            Updated      = $updated
            Locators     = $locators
        }
    } finally {
        $stream.Dispose()
    }
}
