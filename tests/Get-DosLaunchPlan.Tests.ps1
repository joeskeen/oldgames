BeforeAll {
    Import-Module "$PSScriptRoot/../src/InstallOldGames" -Force
}

Describe 'Get-DosLaunchPlan' {
    BeforeEach {
        $script:base = @{
            RelativeProgramDir = '../../programs/doom'
            DiscImageNames     = @('doom.iso')
            TargetDir          = 'C:\GAMES\DOOM'
            ExePath            = 'C:\GAMES\DOOM\DOOM.EXE'
            Rest               = '-warp 1'
            TmpDir             = '/tmp/oldgames/programs/doom/tmp'
        }
    }

    It 'shell mode runs the program from the built-in DOS and exits' {
        $plan = Get-DosLaunchPlan -Mode shell @base -ExitWhenDone

        $plan.AutoExec.Contains('vhdmake -l ../../programs/doom/hdd.vhd hdd.vhd') | Should -BeTrue
        $plan.AutoExec.Contains('imgmount d "../../programs/doom/doom.iso" -t cdrom') | Should -BeTrue
        $plan.AutoExec.Contains('CD C:\GAMES\DOOM') | Should -BeTrue
        $plan.AutoExec.Contains('C:\GAMES\DOOM\DOOM.EXE -warp 1') | Should -BeTrue
        $plan.AutoExec.Contains("`nexit") | Should -BeTrue
        $plan.Files.Count | Should -Be 0
    }

    It 'boot mode hooks the guest AUTOEXEC.BAT and shuts down afterwards' {
        $plan = Get-DosLaunchPlan -Mode boot @base -ExitWhenDone

        $plan.AutoExec.Contains('imgmount d "../../programs/doom/doom.iso" -t cdrom') | Should -BeTrue
        $plan.AutoExec.Contains('COPY B:\RUN.BAT A:\') | Should -BeTrue
        $plan.AutoExec.Contains('COPY B:\CDVOL.COM A:\') | Should -BeTrue
        $plan.AutoExec.Contains('COPY Z:\BIN\SHUTDOWN.COM A:\') | Should -BeTrue
        $plan.AutoExec.Contains('IF NOT EXIST C:\AUTOEXEC.SAV COPY C:\AUTOEXEC.BAT C:\AUTOEXEC.SAV') | Should -BeTrue
        $plan.AutoExec.Contains('COPY C:\AUTOEXEC.SAV C:\AUTOEXEC.BAT') | Should -BeTrue
        $plan.AutoExec.Contains('ECHO CALL A:\RUN.BAT >> C:\AUTOEXEC.BAT') | Should -BeTrue
        $plan.AutoExec.Contains('ECHO A:\SHUTDOWN.COM S >> C:\AUTOEXEC.BAT') | Should -BeTrue
        $plan.AutoExec.EndsWith('BOOT C:') | Should -BeTrue

        $runBat = $plan.Files['run.bat']
        $runBat | Should -Not -BeNullOrEmpty
        $runBat.Contains('A:\CDVOL.COM') | Should -BeTrue
        $runBat.Contains('C:\GAMES\DOOM\DOOM.EXE -warp 1') | Should -BeTrue
        $runBat.Contains("`r`n") | Should -BeTrue
    }

    It 'omits the exit/shutdown steps when -ExitWhenDone is not set' {
        $shell = Get-DosLaunchPlan -Mode shell @base
        $shell.AutoExec.Contains("`nexit") | Should -BeFalse

        $boot = Get-DosLaunchPlan -Mode boot @base
        $boot.AutoExec.Contains('COPY Z:\BIN\SHUTDOWN.COM') | Should -BeFalse
        $boot.AutoExec.Contains('ECHO A:\SHUTDOWN.COM') | Should -BeFalse
    }

    It 'omits the CD and CD commands when there is no disc or target directory' {
        $plan = Get-DosLaunchPlan -Mode shell @base -DiscImageNames @() -TargetDir '' -ExitWhenDone
        $plan.AutoExec.Contains('imgmount d') | Should -BeFalse
        $plan.AutoExec.Contains('REM The target has no directory to switch to') | Should -BeTrue
    }
}
