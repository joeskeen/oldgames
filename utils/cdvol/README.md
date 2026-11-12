# CDVOL.COM

A small DOS TSR that makes an in-game CD audio volume control work when
DOSBox-X boots a real DOS image.

## Why

Under a real DOS boot, the guest's `MSCDEX.EXE` implements the game's CD
volume changes by sending an ATAPI `MODE SELECT` page `0x0E` (CD audio
control) to the emulated drive. DOSBox-X logs that page but does not apply
it to its CD-audio mixer channel, so the game's slider appears to do
nothing and only the host `MIXER CDROM` level has any effect.

The Sound Blaster mixer's CD volume registers (SB16 `0x36`/`0x37`) *are*
wired to the CD-audio mixer channel. `CDVOL.COM` hooks
`INT 2F/AX=1510` (the MSCDEX device-driver request entry point) and, for
IOCTL output subfunction `0x03` ("control audio channel"), copies the
requested left/right volumes into the SB mixer. The TSR reads the SB base
address from the `BLASTER` environment variable (defaulting to A220h) and
does nothing if the guest never changes the CD volume. It relies on
DOSBox-X's Sound Blaster mixer being enabled (`sbmixer=true`, the default).

`Start-Program.ps1` copies `CDVOL.COM` to the boot floppy, and the boot
`RUN.BAT` runs it before the game. It is only used for `DOS_MODE=boot`;
in shell mode DOSBox-X's built-in MSCDEX already forwards the volume.

## Volume mapping

The SB16 CD mixer is a 5-bit, roughly 2 dB/step attenuator. Mapping the
game's linear 0-255 volume directly to the 5-bit index makes mid-range
settings far too quiet (53% becomes about -30 dB). `CDVOL.COM` maps linear
amplitude to the nearest dB index instead, so the displayed percentage is
approximately correct (53% becomes about -6 dB). The overall level tracks
the game's control, but the mixer only has 32 hardware steps; very small
slider movements can fall within one step.

The TSR also re-applies the last CD volume on every timer tick (`INT 1Ch`).
The guest's SB driver (or a track change) can reset the SB mixer after the
MSCDEX volume call; the tick makes the setting stick.

## Gotchas / design notes

- MSCDEX IOCTL output is `INT 2F/AX=1510`; `ES:BX` is the request header,
  the header function is `0x0C`, the buffer pointer is at `+0x0E`/`+0x10`,
  the IOCTL subfunction is `0x03`, and the left/right volumes are at buffer
  `+2`/`+4`. Chain to the previous INT 2F handler; load the TSR after MSCDEX.
- The `BLASTER` parser must advance past `BLASTER=` before searching for the
  `A` base. Searching from the start finds the `A` in "BLASTER" and produces
  mixer port `0x0004`.
- The SB16 CD registers are `0x36`/`0x37` at `base+4`/`base+5`
  (A220 → `0x224`/`0x225`); `sbmixer=true` is required.
- The SB16 CD mixer has 32 ~2 dB steps; the TSR uses a 256-entry
  linear→dB table. Writing the raw linear index makes mid-range volumes far
  too quiet.
- The timer re-apply is intentional: the guest SB driver can reset the
  mixer after the volume call.
- The debug build (`nasm -DCDVOL_SERIAL ...`) writes raw volumes to COM1;
  pair it with `[serial] serial1=file file:cdvol-serial.txt timeout:1000`
  in the DOSBox-X config. `CDTEST.COM` checks the mapped register values
  (`C8 E0` for 0x40/0x80) with a synthetic MSCDEX call.
- To confirm the TSR is alive in a running session, read the SB mixer via
  the debugger: `OUTP 224 36`, `INP 225`, then `OUTP 224 37`, `INP 225`
  (all values hex); the values should follow the game's slider.
- To verify a game: mount its CD image with `-t cdrom`, open its CD-volume
  screen, and move the slider 0↔100; the SB mixer registers should follow
  (read them as described above). `MIXER CDROM` independently confirms the
  host `CDAUDIO` channel.

## Build

Requires `nasm`:

```powershell
nasm -f bin -o CDVOL.COM cdvol.asm
```

## Diagnostic

`cdtest.asm` sends a synthetic MSCDEX volume command (left 0x40, right
0x80) and writes the resulting SB mixer register values to
`A:\CDTEST.BIN`, which should contain `C8 E0` (the TSR maps the synthetic
linear volumes to SB16 indices 25 and 28):

```powershell
nasm -f bin -o CDTEST.COM cdtest.asm
```

A serial-debug build of the TSR can also be produced with
`nasm -DCDVOL_SERIAL -f bin -o CDVOLDBG.COM cdvol.asm`; it emits the
left/right volumes to COM1 so a DOSBox-X `[serial] serial1=file ...`
capture can show live volume changes.
