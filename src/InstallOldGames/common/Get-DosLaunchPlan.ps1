function Get-DosLaunchPlan {
    [CmdletBinding()]
    param(
        # 'shell' runs the game from DOSBox-X's built-in DOS.
        # 'boot' boots the DOS disk image and launches the game from the guest's
        # AUTOEXEC.BAT (some games only behave correctly after a real DOS boot).
        [Parameter(Mandatory = $true)]
        [ValidateSet('shell', 'boot')]
        [string]$Mode,

        [Parameter(Mandatory = $true)]
        [string]$RelativeProgramDir,

        [Parameter()]
        [string[]]$DiscImageNames = @(),

        [Parameter()]
        [string]$TargetDir = '',

        [Parameter(Mandatory = $true)]
        [string]$ExePath,

        [Parameter()]
        [string]$Rest = '',

        [Parameter(Mandatory = $true)]
        [string]$TmpDir,

        [Parameter()]
        [switch]$ExitWhenDone
    )

    $cdFlags = '-t cdrom'
    $discLines = @($DiscImageNames | Where-Object { $_ } | ForEach-Object {
        "imgmount d `"$RelativeProgramDir/$_`" $cdFlags"
    })

    $cdLine = if ($TargetDir) { "CD $TargetDir" } else { 'REM The target has no directory to switch to' }
    $launchLine = "$ExePath $Rest".Trim()

    if ($Mode -eq 'shell') {
        $lines = @(
            '@echo on'
            'cls'
            ''
            '# create the user savedata image from the game install image'
            "vhdmake -l $RelativeProgramDir/hdd.vhd hdd.vhd"
            'imgmount c hdd.vhd'
            ''
            '# mount the game disc image(s)'
        ) + $discLines + @(
            ''
            '# CD audio master level; the built-in MSCDEX forwards the game''s volume control'
            'MIXER CDROM 40'
            ''
            '# run the program from the built-in DOS'
            'C:'
            $cdLine
            $launchLine
        )
        if ($ExitWhenDone) {
            $lines += 'exit'
        }
        $files = @{}
    } else {
        $lines = @(
            '@echo on'
            'cls'
            ''
            '# create the user savedata image from the game install image'
            "vhdmake -l $RelativeProgramDir/hdd.vhd hdd.vhd"
            'imgmount c hdd.vhd'
            ''
            '# mount the game disc image(s)'
        ) + $discLines + @(
            ''
            '# CD audio master level; the guest ATAPI driver cannot control it, so CDVOL.COM mirrors it'
            'MIXER CDROM 40'
            ''
            '# stage RUN.BAT, CDVOL.COM (CD volume -> SB mixer) and SHUTDOWN.COM'
            'imgmake -t fd_1440 fd.img -force'
            'imgmount a -t floppy fd.img -nocachedir'
            "mount b $TmpDir"
            'COPY B:\RUN.BAT A:\'
            'COPY B:\CDVOL.COM A:\'
        )
        if ($ExitWhenDone) {
            $lines += 'COPY Z:\BIN\SHUTDOWN.COM A:\'
        }
        $lines += @(
            'mount -u b'
            ''
            '# preserve the image''s AUTOEXEC.BAT and append the game launch'
            'IF NOT EXIST C:\AUTOEXEC.SAV COPY C:\AUTOEXEC.BAT C:\AUTOEXEC.SAV'
            'COPY C:\AUTOEXEC.SAV C:\AUTOEXEC.BAT'
            'ECHO SET BLASTER=A220 I7 D1 H5 T6 >> C:\AUTOEXEC.BAT'
            'ECHO CALL A:\RUN.BAT >> C:\AUTOEXEC.BAT'
        )
        if ($ExitWhenDone) {
            $lines += 'ECHO A:\SHUTDOWN.COM S >> C:\AUTOEXEC.BAT'
        }
        $lines += 'BOOT C:'

        $runBat = "@echo off`r`nA:\CDVOL.COM`r`nC:`r`n$cdLine`r`n$launchLine`r`n"
        $files = @{ 'run.bat' = $runBat }
    }

    Write-Output @{
        AutoExec = ($lines -join "`n")
        Files    = $files
    }
}
