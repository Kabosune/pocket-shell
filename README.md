# Pocket Shell

A phone-style, Material 3–inspired shell for Linux gaming handhelds, built with
[Quickshell](https://quickshell.org) on [Hyprland](https://hyprland.org) and
designed for both touch and controller.

First target: **Retroid Pocket 5** running **pocknix-os**.

> **Status:** early. The Home screen (landscape) works with touch and controller:
> clock, media controls, Wi-Fi and Bluetooth toggles, battery, and a dock.
> Other pages, app launching and portrait layout are still to come.

## Layout

| Path | What it is | Installed to |
| --- | --- | --- |
| `hypr/hyprland.lua` | Hyprland config (0.56+ uses Lua, not `hyprland.conf`) | `~/.config/hypr/hyprland.lua` (symlink) |
| `quickshell/` | The shell itself (`Theme.qml` tokens, `Device.qml` profile, screens) | `~/.config/quickshell` (symlink) |
| `fonts/` | Archivo, Manrope, Nunito (SIL Open Font License, see each folder) | `~/.local/share/fonts/pocket-shell` (symlink) |
| `input/` | `pocket-input`, a small SDL3 gamepad reader the shell runs | `/usr/local/bin/pocket-input` (built) |
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

| Button | Home | Session sheet |
| --- | --- | --- |
| D-pad / left stick | Move focus (media · toggles · dock) | Move focus |
| A | Activate | Activate |
| B | — | Close |
| Start | Open the session sheet | Close |
| Home | Jump to the dock | Close |

Buttons are named by the letter printed on the controller, as SDL reports
it. To see what the shell receives, run `pocket-input` over SSH and press
buttons; each press prints a line like `down a`.

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
