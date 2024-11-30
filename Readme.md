# OldGames

Making it possible to run old MS-DOS or early Windows games super easily.

## Initial Setup

### Installing DosBox-X

Install DosBox-X. Binaries, source, and installation instructions for your OS are available at <https://dosbox-x.com/>.

Make sure once it is installed, that the command `dosbox-x` is available in your terminal (in a directory referenced by your `PATH` environment variable).

### Installing PowerShell

You will need to install the cross-platform version of PowerShell, regardless of the OS you are using. Binaries, source, and installation instructions are available at <https://github.com/PowerShell/PowerShell/releases/latest>.

Make sure once it is installed, that the command `pwsh` is available in your terminal (in a directory referenced by your `PATH` environment variable).

### Setting up Windows 98

All of these steps are done in the `envs/win9x` directory.

1. Download a Windows 98 SE ISO. I got mine from [WinWorld](https://winworldpc.com/product/windows-98/98-second-edition). Save it in this directory as `Win98SE.iso`.
1. Edit the `dosbox-x.conf` file in this directory, changing the `core=dynamic_x86` to `core=normal`. Also change the autoexec to boot from the CD-ROM (those two lines are commented out).
1. Run dosbox-x in this directory with `-conf dosbox-x.conf`. This will create the hard disk image for you (so you don't have to).
1. Follow the rest of the [DosBox-X Windows 98 installation guide](https://dosbox-x.com/wiki/Guide:Installing-Windows-98).
1. I'd highly recommend doing the optional last bit of the guide to copy the Windows 98 sources to the hard disk image. This will make it easier to install drivers and such later on.
1. If you will want to use the CD-ROM from DOS:
    1. Download a Windows 98 Boot Disk. I got mine from [WinWorld](https://winworldpc.com/product/microsoft-windows-boot-disk/98-se). Extract and save it in this directory as `Win98SE-boot.img`.
    1. Open DosBox-X, mount hdd.vhd as C:, and mount Win98SE-boot.img as A:.
    1. Copy `OAKCDROM.SYS` from A: to C:.
    1. Add the following lines to CONFIG.SYS:
        ```
        DEVICE=C:\WINDOWS\HIMEM.SYS /TESTMEM:OFF
        DEVICEHIGH=C:\OAKCDROM.SYS /D:cd001
        ```
    1. Add the following lines to AUTOEXEC.BAT:
        ```
        LOADHIGH C:\WINDOWS\COMMAND\MSCDEX.EXE /D:cd001
        ```
1. You probably don't want the super long Windows start-up sound to play every time you launch a game. To disable it, open the Control Panel, go to Sounds, and change the "Start Windows" sound to "(None)".
1. Make any other tweaks you want to the Windows 98 environment. **Once you start setting up games, changes to this image will not propagate to the game images.**

## Installing a Game

All of these steps are done in the root directory of this repository.

1. Identify the disk image file(s) for your game. Know the full path to each file.
1. Run `./New-Program.ps1 -Name "Game Name" -EnvType "win9x" -DiskImagePaths "path/to/disk1.iso", "path/to/disk2.iso"`. This will create a new directory in the `programs` directory with the name of the game, containing a differencing disk image for for the game. (What differencing disk images do is allow you to make changes to the game's disk image without affecting the original Windows 98 disk image. This way multiple games or their dependencies will not interfere with each other.)
1. The DosBox-X window will open, and boot into Windows 98 with the game's disk image mounted. You can now install the game as you would on a real Windows 98 machine.
1. Note the full path (inside Windows 98) to launch the game. You will need that later. An easy way to find this is to open the Start menu, right-click on the game's shortcut, and select Properties. The "Target" field will have the full path.
1. When you are done, shut down Windows 98. The installed game will be saved in the differencing disk image.
1. If your game install requires a reboot to finish setting up, go ahead and reboot. The `New-Program.ps1` script will ask you if you need to reboot, and will handle it for you.
1. If you need to make changes to the game's disk image later, you can run `dosbox-x -conf install.dosbox-x.conf` from the game's directory. This will mount the game's disk image and boot into Windows 98. Make your changes, and shut down Windows 98 when you are done. The changes will be saved in the differencing disk image.
1. Note that the program's directory name has been normalized to be a valid directory name. This is the name you will use to run the game.

## Running a Game

All of these steps are done in the root directory of this repository.

1. Run `./Start-Program.ps1 "game-name"`. This will create a differencing disk image for your user based on the game image and launch the game. This allows multiple users to run the same game with their own settings and savegames without clobbering each other.

## License

This project is licensed under the MIT License - see the [LICENSE](./LICENSE) file for details.
