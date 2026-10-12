# Pocket Shell

A phone-style, Material 3–inspired shell for Linux gaming handhelds, built with
[Quickshell](https://quickshell.org) on [Hyprland](https://hyprland.org) and
designed for both touch and controller.

First target: **Retroid Pocket 5** running **pocknix-os**.

> **Status:** early, landscape only. Four pages work with touch and controller:
> Home (clock, media, toggles, a dock of pinned apps), Library (your games,
> with box art), Apps (everything installed) and Glance (battery, storage and
> more). Apps and games open on top of the shell; Home brings you back and
> holding Home shows Recents. Portrait, dual-screen and an on-screen keyboard
> are still to come.

## Layout

| Path | What it is | Installed to |
| --- | --- | --- |
| `hypr/hyprland.lua` | Hyprland config (0.56+ uses Lua, not `hyprland.conf`) | `~/.config/hypr/hyprland.lua` (symlink) |
| `quickshell/` | The shell itself (`Theme.qml` tokens, `Device.qml` profile, screens) | `~/.config/quickshell` (symlink) |
| `fonts/` | Archivo, Manrope, Nunito (SIL Open Font License, see each folder) | `~/.local/share/fonts/pocket-shell` (symlink) |
| `input/` | `pocket-input`, a small SDL3 gamepad reader the shell runs | `/usr/local/bin/pocket-input` (built) |
| `bin/pocket-games` | Finds games for the Library and works out their emulator commands | `/usr/local/bin/` (copy) |
| `session/pocketshell-session` | Session launcher | `/usr/local/bin/` (copy) |
| `session/pocketshell.desktop` | Wayland session entry | `/usr/share/wayland-sessions/` (copy) |
| `devices/` | Per-device notes and profiles | — |
| `install.sh` | Sets up all of the above | — |

## Install (pocknix-os on RP5)

Hyprland and Quickshell aren't in pocknix's locked package snapshot, so switch
the base to rolling first:

```bash
sudo pocknix-base rolling
```

For controller support, install the build tools and SDL3 (once):

```bash
sudo pacman -S --needed gcc make pkgconf sdl3
```

Then clone and install:

```bash
git clone https://github.com/Kabosune/pocket-shell.git ~/pocket-shell
```

```bash
~/pocket-shell/install.sh
```

`install.sh` backs up any existing config with a `.bak-<date>` suffix before
linking. After that, `git pull` in `~/pocket-shell` updates the configs in place.
Re-run `install.sh` when the session files or the controller helper change.

Switch to Pocket Shell, and back:

```bash
pocknix-desktop-select pocketshell --now
```

```bash
pocknix-desktop-select plasma-mobile --now
```

## Controls

Touch works everywhere. With a controller, the first D-pad or A press shows
the focus ring; touching the screen hides it again.

Anywhere in the shell:

| Button | Does |
| --- | --- |
| L1 / R1 | Previous / next page (Home · Library · Apps · Glance) |
| B | Back; on a page's top level, back to Home |
| Start | Session menu (Plasma Mobile, Steam mode) |
| Home | Back to the Home page; from an app or game, back to the shell |
| Hold Home | Recents: switch to (A) or close (X) open apps |

On each page:

| Page | D-pad / stick | A | Other |
| --- | --- | --- | --- |
| Home | Move between media, toggles and dock | Activate | |
| Library | Move between collections, then games | Open / play | LT RT filter, X refresh |
| Apps | Move around the grid | Open | X pin to / unpin from the dock |
| Glance | Choose a media button | Press it | |

While an app or game is in front, only Home and hold-Home go to the shell;
everything else stays with the app.

Buttons are named by the letter printed on the controller, as SDL reports
it. To see what the shell receives, run `pocket-input` over SSH and press
buttons; each press prints a line like `down a`.

## Apps and windows

The shell sits on Hyprland's bottom layer, under app windows. Workspace 1 is
kept empty as "home". Each app or game launched from the shell opens on its
own empty workspace, so Home is just a switch back to workspace 1, and
Recents lists the open windows.

Long-press an app in the Apps page (or press X) to pin it to the Home dock.
Pins and recently played games are saved in Quickshell's state folder
(`~/.local/state/quickshell/by-shell/.../state.json`).

## Library

The Library reads the same folders pocknix's ES-DE setup uses:

- **ROMs:** `~/Emulation`, one folder per system using ES-DE's names
  (`n64`, `gba`, `psx`, `ps2`, `psp`, `gc`, …). If `~/Emulation/roms` exists,
  that's used instead.
- **Box art:** ES-DE's scraped media, from its default folder `~/ES-DE/downloaded_media/<system>/covers`
  (falls back to miximages, then screenshots). Scrape in ES-DE once and the
  art shows up here.
- **Ports:** `.sh` launch scripts in `~/Emulation/ports`.
- **Android:** Waydroid apps, from their desktop entries.
- **Steam:** opens Steam mode, where the Steam library lives.

Games launch with the emulators pocknix lists (RetroArch cores, Dolphin,
PPSSPP, Azahar, ARMSX2). `bin/pocket-games` holds the system table and looks
for RetroArch cores in the usual folders. To check what a game would run:

```bash
pocket-games command n64 "$HOME/Emulation/n64/Some Game.z64"
```

If a system won't start, that command says what's missing. The folders can be
changed with `POCKET_ROMS`, `POCKET_MEDIA` and `POCKET_PORTS`.

## Write-up: getting Hyprland to start from Plasma on pocknix

Selecting a non-KDE desktop with `pocknix-desktop-select <name> --now` gave a
black screen. Hyprland's log showed DRM "Permission denied", a `0x0` mode for
`DSI-1`, and a fallback `WAYLAND-1` headless output.

**Cause.** Plasma 6 runs KWin as a systemd *user service*
(`plasma-kwin_wayland.service`). When pocknix switches sessions, that service
keeps running for about 4 seconds and still holds the DRM device. A compositor
that starts inside that window can't become DRM master.

**Fix.** `session/pocketshell-session` stops `plasma-workspace.target`, waits up
to 10 seconds for `plasma-kwin_wayland.service` to go inactive, clears
`WAYLAND_DISPLAY` and `DISPLAY` (so Hyprland doesn't think it's nested), then
`exec`s `start-hyprland`. Hyprland uses the default seatd backend, which is what
pocknix already runs for gamescope. An experiment with
`LIBSEAT_BACKEND=logind` wasn't needed and was removed.

Other things that cost time:

- **Hyprland 0.56 uses a Lua config** (`hyprland.lua`). Old `hyprland.conf`
  guides don't apply directly.
- **The RP5 panel is natively portrait** and its EDID doesn't parse. Set the
  mode explicitly (`1080x1920@60`) and rotate with transform `1`.
- **Touch needs its own mapping.** Bind the touch device to `DSI-1` with the
  same transform, or touches land in the wrong place.
- **Hyprland's file logs are off by default.** A short log doesn't mean a hang.
  Set `debug.disable_logs = false` and collect the full log and journal before
  guessing.

This is also being reported upstream to pocknix, since `--now` could wait for
the old session's compositor itself.

## Credits

- KaboWabo/Kabosune (me :3)
- AI assistance (Claude Opus 5.5)
- Fonts: [Archivo](https://github.com/Omnibus-Type/Archivo),
  [Manrope](https://github.com/googlefonts/manrope) and
  [Nunito](https://github.com/googlefonts/nunito), by their project authors,
  under the SIL Open Font License 1.1
