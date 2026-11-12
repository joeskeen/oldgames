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
  `icoutils` (provides `wrestool`) and ImageMagick 7 (provides `magick`). Install them with
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

### Setting up MS-DOS

All of these steps are done in the `envs/dos` directory.

1. Get the MS-DOS 6.22 installation media (three 1.44 MB disk images, or an ISO).
1. Run `dosbox-x -conf dosbox-x.conf` in this directory. This creates `hdd.vhd` (2 GB) and tries to boot it.
1. Boot from the DOS setup media instead (for example `imgmount a Disk1.img -t floppy` followed by `BOOT A:`), then:
    1. `FDISK` — create a primary DOS partition (reboot afterwards).
    1. `FORMAT C: /S` — format it and make it bootable.
    1. Run `SETUP` to install MS-DOS to `C:\DOS`.
1. Copy a CD-ROM driver and `MSCDEX.EXE` into the image (the Windows 98 boot disk from the previous section has both):
    - `OAKCDROM.SYS` → `C:\`
    - `MSCDEX.EXE` → `C:\DOS\`
1. Edit `C:\CONFIG.SYS` and `C:\AUTOEXEC.BAT` for memory, CD-ROM and sound, for example:
    ```
    DEVICE=C:\DOS\HIMEM.SYS
    DEVICE=C:\DOS\EMM386.EXE RAM
    DOS=HIGH,UMB
    FILES=40
    BUFFERS=20
    DEVICEHIGH=C:\OAKCDROM.SYS /D:cd001
    ```
    ```
    @ECHO OFF
    PROMPT $P$G
    PATH C:\DOS
    SET BLASTER=A220 I7 D1 T6
    LH C:\DOS\MSCDEX.EXE /D:cd001
    ```
1. Make sure `dosbox-x.conf` boots the hard disk (`BOOT C:`, the default) and close DOSBox-X.

Games are installed with `-EnvType dos`, which boots this image and mounts the game media as `D:`.

## Hosting Games on a NAS

You can keep a single copy of the games on a NAS and keep each person's savedata
in a per-user directory on the same NAS:

```
/mnt/nas/games/oldgames              # scripts, envs and programs
/mnt/nas/games/users/alice/.oldgames # alice's savedata
/mnt/nas/games/users/bob/.oldgames   # bob's savedata
```

Put the whole working tree on the NAS, so `$PSScriptRoot` points at the NAS copy.
Copy it with `rsync -a` (or similar), not a fresh `git clone`: the game images,
environment disks and some helpers are gitignored and would not be cloned. Keep
`envs/` and `programs/` together under the same repository root: each game's
`hdd.vhd` is a differencing disk whose parent is the environment image, and its
recorded relative path assumes that layout.

### Configuring the data root

Create `/etc/oldgames/config.json` on each lab machine:

```json
{
  "userDataRoot": "/mnt/nas/games/users/{user}/.oldgames"
}
```

A starter file is included in the repository:

```shell
sudo install -Dm644 config/oldgames.example.json /etc/oldgames/config.json
```

`{user}` is replaced with the Linux login name (`$USER`). `~` and `$HOME` are
also expanded. The data root is resolved in this order, highest priority first:

1. `-UserDataRoot` on `Start-Program.ps1`
2. `OLDGAMES_USER_DATA_ROOT`
3. `~/.config/oldgames/config.json`
4. `/etc/oldgames/config.json`
5. the default, `~/.config/oldgames`

The configuration file is JSON, not a PowerShell script, so a system-wide file
cannot execute code. Unknown keys produce a warning. Because the file is read
per machine, the NAS mount path may differ from machine to machine.

The directory *above* the data root must already exist, for example
`/mnt/nas/games/users/alice`. This is deliberate: if the NAS is not
mounted, the launcher stops with an error instead of silently creating a local
directory that shadows the NAS path. Create each person's parent directory once:

```shell
sudo mkdir -p /mnt/nas/games/users/alice
sudo chown alice:alice /mnt/nas/games/users/alice
```

### What stays on each machine

Only the savedata moves to the NAS. These remain machine-local:

- Desktop entries: `~/.local/share/applications`, or
  `/usr/share/applications` with `-InstallScope system`.
- The DOSBox-X debugger port file: `~/.config/oldgames/dosbox-mcp-port`.
- Icon-search scratch files: `~/.cache/oldgames`.

Run `Install.ps1` once on each machine. In a multi-user lab, install the entries
system-wide so every account gets them:

```shell
sudo ./Install.ps1 -InstallScope system
```

If DOSBox-X is a Flatpak, pass the same `-DosBoxXCommand "flatpak run com.dosbox_x.DOSBox-X"`
you use elsewhere; desktop entries do not inherit your shell environment.

The entry runs `Start-Program.ps1` from the NAS and uses the icon from the NAS,
so nothing but the small `.desktop` file is copied per machine. It invokes
`pwsh` explicitly, so it also works when the NAS is mounted `noexec`. When
launching from a terminal on a `noexec` mount, use `pwsh ./Start-Program.ps1 ...`
for the same reason.

### Migrating existing savedata

If you already have savedata in `~/.config/oldgames`, migrate it to the
configured data root:

```shell
./Migrate-UserData.ps1
```

The script copies files; it does not delete the source. It also rewrites each
savedata VHD's recorded parent path. That step is required because a
differencing VHD stores both an absolute and a relative path to its parent
inside the file; a plain copy to a different location would no longer mount.
Re-run with `-Force` to overwrite files already present in the destination. If
the scripts run from a different checkout than the programs, pass
`-ProgramsRoot /path/to/programs`. After verifying that games start and saves
are present, the old `~/.config/oldgames` tree can be removed manually.

### Concurrency and performance

There is no cross-machine lock. Do not run the same person's game on two lab
machines at the same time: both would open the same savedata VHD read/write and
could corrupt it. Different people, and different games for the same person, are
fine.

SMB/NFS latency affects disk-image reads. The games are small, but the first
launch of a game is slower than from a local disk.

## Installing a Game

All of these steps are done in the root directory of this repository.

1. Identify the disk image file(s) for your game. Know the full path to each file.
1. Run `./New-Program.ps1 -ProgramName "Game Name" -EnvType "win9x" -DiskImagePaths "path/to/disk1.iso", "path/to/disk2.iso"`. This will create a new directory in the `programs` directory with the name of the game, containing a differencing disk image for for the game. (What differencing disk images do is allow you to make changes to the game's disk image without affecting the original Windows 98 disk image. This way multiple games or their dependencies will not interfere with each other.) For a DOS game use `-EnvType dos`; add `-DosMode boot` if the game only behaves correctly after a real DOS boot (see [Running a Game](#running-a-game)).
1. The DosBox-X window will open, and boot into Windows 98 with the game's disk image mounted. You can now install the game as you would on a real Windows 98 machine.
1. Note the full path (inside Windows 98) to launch the game. You will need that later. An easy way to find this is to open the Start menu, right-click on the game's shortcut, and select Properties. The "Target" field will have the full path.
1. When you are done, shut down Windows 98. The installed game will be saved in the differencing disk image.
1. If your game install requires a reboot to finish setting up, go ahead and reboot. The `New-Program.ps1` script will ask you if you need to reboot, and will handle it for you.
1. If you need to make changes to the game's disk image later, you can run `dosbox-x -conf install.dosbox-x.conf` from the game's directory. This will mount the game's disk image and boot into Windows 98. Make your changes, and shut down Windows 98 when you are done. The changes will be saved in the differencing disk image.
1. Note that the program's directory name has been normalized to be a valid directory name. This is the name you will use to run the game.

## Running a Game

All of these steps are done in the root directory of this repository.

1. Run `./Start-Program.ps1 "game-name"`. This will create a differencing disk image for your user based on the game image and launch the game. This allows multiple users to run the same game with their own settings and savegames without clobbering each other. Add `-DosBoxXCommand "flatpak run com.dosbox_x.DOSBox-X"` if DOSBox-X is installed as a Flatpak. If user data lives on a NAS, see [Hosting Games on a NAS](#hosting-games-on-a-nas); `-UserDataRoot` overrides the configured path for a single launch.

### DOS games: built-in DOS vs. booted DOS

DOS games have two launch modes, selected at install time with `-DosMode`:

- `shell` (default) — DOSBox-X runs the game from its built-in DOS. This is the fastest option and works for most games.
- `boot` — DOSBox-X boots the game's DOS image first and launches the game from the guest's `AUTOEXEC.BAT`. Use this for the edge cases where a game only behaves correctly after a real DOS boot. The image's original `AUTOEXEC.BAT` is preserved as `AUTOEXEC.SAV` and restored before each launch; after the game exits, `SHUTDOWN.COM S` powers off DOSBox-X.

CD audio volume controlled from inside a game is handled differently depending on the launch mode. DOSBox-X ignores the ATAPI `MODE SELECT` page `0x0E` volume command that a real DOS boot's MSCDEX sends, so boot-mode launches copy `utils/cdvol/CDVOL.COM` to the floppy and load it before the game. It is a small TSR that mirrors the game's MSCDEX volume command to the Sound Blaster mixer's CD registers, which DOSBox-X *does* apply to the CD-audio channel. In `shell` mode the built-in MSCDEX already forwards the volume, so the TSR is not needed. The launch plan sets `MIXER CDROM 40` as an initial level; the game's own control takes over once it starts. The SB16 CD mixer is a 32-step, roughly 2 dB/step attenuator, so `CDVOL.COM` maps the game's linear volume onto it: the displayed percentage is approximately correct, but very small slider movements can fall within one hardware step.

### CD audio: lessons learned

DOSBox-X has one host CD-audio channel, `CDAUDIO`; `MIXER CDROM <0-100>` sets its initial level. A game's own CD-volume control takes one of two paths:

- **DOS shell mode** — DOSBox-X's built-in MSCDEX applies the game's volume command directly (smooth, 8-bit).
- **Real DOS boot** — the guest MSCDEX turns it into an ATAPI `MODE SELECT` page `0x0E`, which DOSBox-X currently logs but does not apply. `utils/cdvol/CDVOL.COM` closes that gap by mirroring the MSCDEX IOCTL to the Sound Blaster mixer's CD registers (which feed `CDAUDIO`).

When using `CDVOL.COM` or a similar helper:

- Keep the game's `SETSOUND`/setup on **Sound Blaster 16** (AWE is also fine); `sbmixer=true` is required. WSS, GUS and other cards do not have the SB mixer CD registers.
- Set `BLASTER=Axxx ...` before the helper loads; it derives the mixer ports as `Axxx+4`/`Axxx+5`.
- The SB16 CD mixer is a **5-bit, ~2 dB/step** attenuator. Map the game's linear 0–255 volume to the nearest dB index; a direct linear index makes mid-range settings (about 53 %) become about −30 dB and virtually inaudible.
- The guest SB driver, or a track change, can reset the mixer after the volume command. Re-apply the last volume on the `INT 1Ch` timer tick.
- The game's options file may use an internal scale (for example, a stored value of `8` may be displayed as 53 %); do not confuse it with the MSCDEX byte.
- Mount CD images with `-t cdrom`; `-ide 2m` broke CD-DA in our tests.

#### Debugging CD-volume issues

1. Confirm CD-DA is playing: the DOSBox-X log shows `CDROM: Playing track # N`.
2. Confirm the host `CDAUDIO` level: `MIXER CDROM 0`/`100` (or Main → Mixer) should change the music. If it does not, the game is not using CD audio or the CD image was not mounted with `-t cdrom`.
3. Determine the launch mode:
   - **shell** — the in-game slider should work through the built-in MSCDEX.
   - **boot** — watch the log while moving the slider. `ATAPI MODE SELECT, PAGE 0x0e` means the game sends the volume but DOSBox-X ignores it; use a helper such as `CDVOL.COM` to mirror it to the SB mixer.
4. With the helper loaded, read the SB16 CD mixer registers via the debugger (`OUTP 224 36`, `INP 225`, then `OUTP 224 37`, `INP 225`; values are hex) while moving the slider. They should change. If they do not, check that the TSR is loaded, `SET BLASTER` is set before it, the BLASTER parser/port (`Axxx+4`), and the MSCDEX request format (`INT 2F/AX=1510`, function `0x0C`, subfunction `0x03`).
5. If the registers change but the music does not, check `sbmixer=true`, the guest's Sound Blaster 16 setup, and that the music is actually CD audio (not MIDI or software-mixed).
6. If the mixer is reset to maximum after the slider, the guest SB driver or a track change is resetting it; re-apply the last volume on `INT 1Ch`.
7. Use a serial build (`nasm -DCDVOL_SERIAL ...` plus `[serial] serial1=file file:...`) to log raw volume commands; `CDTEST.COM` gives a synthetic check.
8. The SB16 CD mixer has 32 × ~2 dB steps; test 0 and 100, not only tiny movements.

For **Windows 9x** games, CD audio still ends up on `CDAUDIO`, but volume normally goes through the guest's Windows mixer/driver rather than MSCDEX. Check whether the driver writes the SB CD registers; otherwise use the DOSBox-X mixer (`MIXER CDROM` or Main → Mixer) as the host-level control. `CDVOL.COM` targets DOS protected-mode games using MSCDEX.

Other launch lessons:

- Configure the sound setup in the **program image**, not only in a per-user savedata image. A newly created savedata image inherits the program image and would otherwise lose `SETUP.CFG`.
- Pass an explicit absolute `-DosBoxXCommand` in desktop entries; desktop sessions may not inherit your shell `PATH`.
- In boot mode use `SHUTDOWN.COM S`; without the argument it prompts `S/R/C`.
- For debugging, launch from a terminal (`Start-Program.ps1`) so the debugger control channel is available. Read the SB16 CD mixer with debugger `OUTP 224 36` and `INP 225` (hex; then `OUTP 224 37`/`INP 225` for the right channel); a `[serial] serial1=file file:...` build of `CDVOL.COM` logs the raw volume commands, and DOSBox-X prints `ATAPI MODE SELECT, PAGE 0x0e` when the guest sends one.

DOS executables do not contain icon resources, so `New-Program` skips icon extraction for `-EnvType dos`.

## Debugging with the DOSBox-X debugger (optional)

DOSBox-X has a built-in debugger, and debugger-enabled builds can expose it to external tools over a local TCP control channel. This is useful for diagnosing why a game misbehaves, hangs, or behaves differently depending on how the environment is booted.

- The control protocol, debugger commands and keyboard shortcuts are documented in the DOSBox-X [README.debugger](https://github.com/joncampbell123/dosbox-x/blob/e2b92bb86382a5444ce42157a37138b459ec98b5/README.debugger#L99) (see "Debugger MCP control protocol").
- [dosbox-x-mcp-server](https://github.com/caiiiycuk/dosbox-x-mcp-server) is an MCP server that lets an agent (for example, OpenCode) drive the debugger: snapshots, breakpoints, raw debugger commands, single-stepping and bounded memory reads.

Enable the control channel in the `[dosbox]` section of an environment or program configuration:

```ini
[dosbox]
mcp_server=58991
```

DOSBox-X then connects to `127.0.0.1:<mcp_server>`; the default value of `0` disables it. Start the MCP server first, then launch the game. It is not a launcher itself: this repository's scripts still create the differencing disks and boot the environment, and DOSBox-X dials out to the debugger server.

**Linux/macOS:** the debugger interface, and therefore the MCP control channel, is only enabled when DOSBox-X is started from a terminal. Games launched from a desktop entry will not expose the debugger; to debug, launch from a terminal instead:

```powershell
./Start-Program.ps1 "game-name"
```

## Installing Desktop Entries

Run `./Install.ps1` to create a desktop entry for every program in the `programs` directory, so the games show up in your application menu. The entry runs `Start-Program.ps1` and uses the program's icon. If DOSBox-X is not on your `PATH` (for example, a Flatpak install), pass the same `-DosBoxXCommand` you use elsewhere — it is embedded into the entry, because desktop sessions do not inherit environment variables from your shell:

```powershell
./Install.ps1 -DosBoxXCommand "flatpak run com.dosbox_x.DOSBox-X"
```

Pass `-InstallScope system` to install the entries for all users (requires write access to `/usr/share/applications`). This is the recommended choice for a shared lab. Desktop entries are machine-local even when games and savedata live on a NAS, so run `Install.ps1` on each machine.

## License

This project is licensed under the MIT License - see the [LICENSE](./LICENSE) file for details.
fullscreen
