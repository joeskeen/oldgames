# OldGames

Making it possible to run old MS-DOS or early Windows games super easily.

## Requirements

- **Linux.** The installation helpers (`Install.ps1`, icon extraction) currently only support Linux.
- **PowerShell 7.4 or later**, available as `pwsh` on your `PATH`.
- **DOSBox-X**, available as `dosbox-x` on your `PATH`. If you installed DOSBox-X as a
  Flatpak, pass `-DosBoxXCommand "flatpak run com.dosbox_x.DOSBox-X"` to the scripts (all
  of them accept it), or set the `OLDGAMES_DOSBOX_X` environment variable to
  `flatpak run com.dosbox_x.DOSBox-X` once instead of passing it every time.
- **Helper programs** used by the installer and by `Copy-OnRemote.ps1`: `rsync`,
  `icoutils` (provides `wrestool`) and ImageMagick (provides `convert`). Install them with
  your distribution's package manager, e.g. `sudo pacman -S rsync icoutils imagemagick`.

## Initial Setup

### Installing DosBox-X

Install DosBox-X. Binaries, source, and installation instructions for your OS are available at <https://dosbox-x.com/>.

Make sure once it is installed, that the command `dosbox-x` is available in your terminal (in a directory referenced by your `PATH` environment variable). If you installed DosBox-X as a Flatpak, it will not be on your `PATH`; see [Requirements](#requirements) for how to point the scripts at it.

### Installing PowerShell

You will need to install the cross-platform version of PowerShell, regardless of the OS you are using. Binaries, source, and installation instructions are available at <https://github.com/PowerShell/PowerShell/releases/latest>.

Make sure once it is installed, that the command `pwsh` is available in your terminal (in a directory referenced by your `PATH` environment variable). PowerShell 7.4 or later is required.

### Setting up Windows 98

All of these steps are done in the `envs/win9x` directory.

1. Download a Windows 98 SE ISO. I got mine from [WinWorld](https://winworldpc.com/product/windows-98/98-second-edition). Save it in this directory as `Win98SE.iso`.
1. Edit the `dosbox-x.conf` file in this directory, changing the `core=dynamic_x86` to `core=normal`. Also change the autoexec to boot from the CD-ROM (those two lines are commented out).
1. Run dosbox-x in this directory with `-conf dosbox-x.conf`. This will create the hard disk image for you (so you don't have to).
1. Follow the rest of the [DosBox-X Windows 98 installation guide](https://dosbox-x.com/wiki/Guide:Installing-Windows-98).
1. I'd highly recommend doing the optional last bit of the guide to copy the Windows 98 sources to the hard disk image. This will make it easier to install drivers and such later on.
1. Copy the MS-DOS build of `sed` into the image, at `C:\WINDOWS\SYSTEM32\SED.EXE` (create the `SYSTEM32` directory if it does not exist). `Start-Program.ps1` uses it to make the guest boot to a DOS prompt before launching games; without it, games will boot to the Windows desktop instead of starting automatically. The binary is in this repository at `utils/sed/SED.EXE`.
1. Optional: install [Another Task Manager](./utils/atm/Readme.md) inside Windows 98. It is also copied to the `A:` floppy on every launch, so you can use it to inspect running processes while a game is running.
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
1. Run `./New-Program.ps1 -ProgramName "Game Name" -EnvType "win9x" -DiskImagePaths "path/to/disk1.iso", "path/to/disk2.iso"`. This will create a new directory in the `programs` directory with the name of the game, containing a differencing disk image for for the game. (What differencing disk images do is allow you to make changes to the game's disk image without affecting the original Windows 98 disk image. This way multiple games or their dependencies will not interfere with each other.)
1. The DosBox-X window will open, and boot into Windows 98 with the game's disk image mounted. You can now install the game as you would on a real Windows 98 machine.
1. Note the full path (inside Windows 98) to launch the game. You will need that later. An easy way to find this is to open the Start menu, right-click on the game's shortcut, and select Properties. The "Target" field will have the full path.
1. When you are done, shut down Windows 98. The installed game will be saved in the differencing disk image.
1. If your game install requires a reboot to finish setting up, go ahead and reboot. The `New-Program.ps1` script will ask you if you need to reboot, and will handle it for you.
1. If you need to make changes to the game's disk image later, you can run `dosbox-x -conf install.dosbox-x.conf` from the game's directory. This will mount the game's disk image and boot into Windows 98. Make your changes, and shut down Windows 98 when you are done. The changes will be saved in the differencing disk image.
1. Note that the program's directory name has been normalized to be a valid directory name. This is the name you will use to run the game.

## Running a Game

All of these steps are done in the root directory of this repository.

1. Run `./Start-Program.ps1 "game-name"`. This will create a differencing disk image for your user based on the game image and launch the game. This allows multiple users to run the same game with their own settings and savegames without clobbering each other. Add `-DosBoxXCommand "flatpak run com.dosbox_x.DOSBox-X"` if DOSBox-X is installed as a Flatpak.

## Installing Desktop Entries

Run `./Install.ps1` to create a desktop entry for every program in the `programs` directory, so the games show up in your application menu. The entry runs `Start-Program.ps1` and uses the program's icon. Pass `-InstallScope system` to install the entries for all users (requires write access to `/usr/share/applications`).

## License

This project is licensed under the MIT License - see the [LICENSE](./LICENSE) file for details.
fullscreen
