# Pocket Shell

A phone-style, Material 3–inspired shell for Linux gaming handhelds, built with
[Quickshell](https://quickshell.org) on [Hyprland](https://hyprland.org) and
designed for both touch and controller.

First target: **Retroid Pocket 5** running **pocknix-os**.

> **Status:** early, landscape only. Four pages work with touch and controller:
> Home (clock, media, toggles, a dock of pinned apps), Library (your games,
> with box art), Apps (everything installed) and Glance (battery, storage and
> more). Apps and games open on top of the shell; Home brings you back,
> holding Home shows Recents and a double tap jumps to the previous app. Quick settings (Select) has brightness, volume
> and toggles, the volume buttons work everywhere, and there are UI sounds.
> Portrait, dual-screen and an on-screen keyboard are still to come.

## Layout

| Path | What it is | Installed to |
| --- | --- | --- |
| `hypr/hyprland.lua` | Hyprland config (0.56+ uses Lua, not `hyprland.conf`) | `~/.config/hypr/hyprland.lua` (symlink) |
| `quickshell/` | The shell itself (`Theme.qml` tokens, `Device.qml` profile, screens) | `~/.config/quickshell` (symlink) |
| `quickshell/themes/` | Built-in themes: Dusk Tide, Dusk Tide Soft, Stylus, Dotfiles, Dotfiles Rain, Static | (part of `quickshell/`) |
| `quickshell/sounds/` | UI sound packs (`soft`, `chip`, `tty`), made by `tools/make-sounds.py` | (part of `quickshell/`) |
| `fonts/` | Archivo, JetBrains Mono, Manrope, Nunito, Press Start 2P (SIL Open Font License, see each folder) | `~/.local/share/fonts/pocket-shell` (symlink) |
| `input/` | `pocket-input`, a small SDL3 gamepad reader the shell runs | `/usr/local/bin/pocket-input` (built) |
| `bin/pocket-games` | Finds games for the Library and works out their emulator commands | `/usr/local/bin/` (copy) |
| `session/pocketshell-session` | Session launcher | `/usr/local/bin/` (copy) |
| `session/pocketshell.desktop` | Wayland session entry | `/usr/share/wayland-sessions/` (copy) |
| `session/pocket-shell.desktop`, `.svg` | "Pocket Shell" app for Plasma Mobile that switches over | `~/.local/share/applications`, `~/.local/share/icons` (symlinks) |
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

For sounds, brightness, the volume buttons, the Static theme's audio
visualizer and `pocket-play` (once):

```bash
sudo pacman -S --needed qt6-multimedia brightnessctl wireplumber cava mpv mpv-mpris yt-dlp
```

`install.sh` lists any of these that are missing; the shell still runs
without them, minus that feature.

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

From Plasma Mobile, you can also tap the **Pocket Shell** app in the app
drawer (pin it to the home screen for one tap). From Pocket Shell, Start →
Plasma Mobile goes the other way.

## Controls

Touch works everywhere. With a controller, the first D-pad or A press shows
the focus ring; touching the screen hides it again.

Anywhere in the shell:

| Button | Does |
| --- | --- |
| L1 / R1 | Previous / next page (Home · Library · Apps · Glance) |
| B | Back; on a page's top level, back to Home |
| Start | Menu: Themes, Sounds on/off, Plasma Mobile, Steam mode |
| Select | Quick settings: brightness, volume, Wi-Fi, Bluetooth (also: tap the status icons) |
| Volume buttons | Change volume anywhere, games included, with an on-screen level |
| Home | Back to the Home page; from an app or game, back to the shell |
| Hold Home | Recents: a picture of each open app, most recent first. A switches, X closes one, Y closes all |
| Double-tap Home | Jump to the previous app (from the shell: to the last app you used) |
| Home + R1 | Screenshot of the main screen, saved to `~/Pictures/Screenshots` (needs `grim`: `sudo pacman -S grim`). Works in apps and games too; the game also sees the R1 press |
| Back (device button) | In the shell, same as B. In an app, that app's own "back": RetroArch opens its menu, web browsers go to the previous page, anything else (Moonlight included) gets Escape |

**The Back button.** Devices driven by InputPlumber with an Xbox 360-style
pad (pocknix on Retroid handhelds, for one) have no Back button on that pad;
InputPlumber normally sends the device's Back as Home, then A 80 ms later,
and every app and game gets that Home + A too. So while Pocket Shell runs,
the session loads its own InputPlumber profile (`input/back-button.yaml`,
via `pocket-back on`) that turns Back into the F20 key instead. Hyprland
catches F20 before any app sees it and tells the shell (`qs ipc call
controller back`). When the session ends, `pocket-back off` puts back the
profile from before, so game mode and Plasma get Back as usual.

Loading a profile needs your user in the `wheel` (or `inputplumber`) group.
If it can't be loaded, the shell still reads Home followed by A within
160 ms as Back, and apps get that Home + A as before. `pocket-back status`
shows which profile is active. The per-app keys live in
`quickshell/AppBack.qml`. `install.sh` sets up RetroArch's controller
profiles and stops Home (Guide) from also opening RetroArch's menu, since
Home belongs to the shell.

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

**Opening apps.** Apps start through Hyprland with a rule that keeps their
window on the workspace they were opened for, so going Home while one is
still loading doesn't make it pop up over the shell. Until the window
shows, that workspace has an "Opening…" screen; pressing the same app again
just brings you back to it instead of starting a second copy, and an app
that's already open comes to the front instead of opening again. B (or
Home) waits on Home; a toast says when it's ready. After 30 seconds
without a window the shell stops waiting. (Some apps start their window
from another process, which the rule can't follow; Steam games, for one.
Those open wherever you are when they're ready.)

**Recents.** Hold Home. Each card shows a still picture of the app (taken
through Hyprland's toplevel export when Recents opens), most recently used
first. Touch: swipe sideways, tap to switch, swipe a card up or tap its ×
to close it, "Close all" at the bottom.

Long-press an app in the Apps page (or press X) to pin it to the Home dock.
Pins and recently played games are saved in Quickshell's state folder
(`~/.local/state/quickshell/by-shell/.../state.json`).

## Quick settings, volume and brightness

Select (or tapping the Wi-Fi/battery icons) pulls down Quick settings: a
brightness slider, a volume slider (tap the speaker or press A to mute)
and the Wi-Fi/Bluetooth toggles. Up/down picks a row, left/right adjusts.

The hardware volume buttons are bound in `hypr/hyprland.lua` to `wpctl`, so
they work in games too; a small volume level pops up over whatever is on
screen. Brightness goes through `brightnessctl` and never drops below 5%,
so the screen can't be turned fully dark by accident.

## pocket-play

Play a YouTube link, a media URL (an `.mp4` on a server, a stream) or a
local file, from a terminal or over SSH:

```bash
pocket-play https://www.youtube.com/watch?v=...
```

To find something to watch, the Now Playing card has a small video button
in its top-right corner: it opens [PlasmaTube](https://apps.kde.org/plasmatube/)
(KDE's YouTube app, `sudo pacman -S plasmatube`) when it's installed, and
YouTube in the browser otherwise. PlasmaTube goes through public Invidious or
Piped servers, which come and go; the browser always works.

`pocket-play` starts with sound only. The Now Playing card shows the title, the channel
and the video's thumbnail (through mpv-mpris), and gets a full-screen
button that shows the video. While the video is up, A pauses, left/right
seek 10 seconds, and B, Back or Home go back to sound only.

| Command | Does |
| --- | --- |
| `pocket-play URL` | Play, sound only |
| `pocket-play --video URL` | Play and show the video full screen |
| `pocket-play --show` / `--hide` | Show the video / back to sound only |
| `pocket-play --pause` | Pause or resume |
| `pocket-play --stop` | Stop |
| `pocket-play --update-ytdlp` | Download the latest yt-dlp to `~/.local/bin` (used when present) |

YouTube changes often and distro builds of yt-dlp fall behind; if YouTube
links stop working, run `pocket-play --update-ytdlp`. Videos play at up to
720p by default (H.264 preferred, never AV1); set `POCKET_PLAY_MAX_HEIGHT`
for more.

## Dark and light apps

Apps follow the theme: a dark background (Dusk Tide's dusk and night,
Dotfiles dark…) tells apps to be dark, a light one (the paper, cream and
dawn backgrounds) light. `bin/pocket-colors` sets GNOME's `color-scheme`
and `gtk-application-prefer-dark-theme` for GTK 3 and 4, which GTK apps and
Firefox's "System theme — auto" read. Apps that are already open may need a
restart to switch. Leaving Pocket Shell puts back the settings from before,
so Plasma keeps its own. `pocket-colors status` shows what apps are told.

## Monitor (USB-C)

Plug a monitor into the USB-C port (a USB-C monitor, or a USB-C to HDMI
adapter or dock with DisplayPort Alt Mode) and Pocket Shell:

- **moves everything to the monitor** at the monitor's own resolution, and
  shows a scaled-down copy on the built-in screen, and
- adds a **Monitor (USB-C)** sound output and makes it the default, so
  sound comes out of the monitor (or speakers plugged into it).

Three picture modes, switched in the Start menu ("Monitor: …", each press
goes to the next) or with `pocket-dock mode match|smooth|rp5`:

| Mode | Drawn for | The other screen |
| --- | --- | --- |
| **Full res** (`match`, default) | The monitor: its biggest 16:9 resolution up to 1440p, at the highest refresh rate up to 120 Hz. Scaled so the shell keeps the RP5's layout (2560×1440 → scale 2.67), just sharper | The RP5 screen shows a copy; touch still works on it |
| **Smooth** (`smooth`) | The monitor, with the highest refresh rate up to 120 Hz first, then the biggest resolution at that rate. Through an adapter that can't do both (one tested here: 1440p only at 60 Hz, 1080p at 120 Hz) this picks 1080p at 120 Hz | The RP5 screen shows a copy; touch still works on it |
| **RP5 1080p** (`rp5`) | The RP5 screen, 1080p at 60 Hz, as in handheld mode | The monitor shows a copy, sent as 1920×1080 at 60 Hz when it has that mode |

Full res costs more GPU in games (1440p is about 1.8× the pixels of 1080p);
switch to RP5 1080p if a game runs slowly docked. The choice is saved
(`~/.config/pocket-shell/dock-mode`) and applied straight away if a monitor
is connected. The refresh rate depends on the cable too: with a hub that
also uses USB 3, the USB-C port has fewer lanes for video, so the monitor
may not offer its top rates.

To see the rate you actually get, open `tools/hz-test.html` in a browser on
the device (it measures how often the browser gets to draw, on the screen
it's on).

Unplugging puts the built-in screen, touch and the sound output back as
they were.
`bin/pocket-dock` does this; Hyprland starts `pocket-dock watch` with the
session. `pocket-dock status` shows what's connected and where sound goes;
`pocket-dock on` / `off` do the same steps by hand.

**Why sound needed help.** pocknix's audio setup (its ALSA UCM profile)
only lists the speaker and headphones, but the kernel has a DisplayPort
output on the RP5's audio router (`DISPLAY_PORT_RX`). `pocket-dock` routes a
playback channel pocknix leaves free (`MultiMedia3`, `hw:0,2`) to it and
gives it to PipeWire. The output stays open while the monitor is connected,
because reopening it straight after closing it can time out.

Known: Valve's Steam Deck Docking Station gives a picture on the RP5 but no
sound, and a kernel warning (`tcpm_queue_vdm`) when plugged in; a plain
USB-C to HDMI adapter worked for both.

## Moonlight (streaming from a PC)

[Moonlight](https://moonlight-stream.org) streams games from a PC running
[Sunshine](https://github.com/LizardByte/Sunshine). Install it on the
device:

```
sudo pacman -S --needed moonlight-qt
```

It then shows up on the Apps page (X pins it to the dock). Pairing needs no
typing on the handheld: open Moonlight, pick your PC (it's found on its own
on the same network), and type the PIN it shows into Sunshine's web page on
the PC.

- **Back**: Escape. In Moonlight's menus that goes back; while streaming it
  reaches the PC as the Escape key. Back itself never reaches the PC.
- **Home**: back to the shell; Moonlight stops reading the controller while
  it isn't in front. Home is the pad's Guide button, though, so the PC also
  gets that press (it may open Steam's overlay).
- **Quit a stream**: Moonlight's own combo, Start + Select + L1 + R1.
- **Typing on the PC**: Steam Big Picture's keyboard (Guide + X) works over
  the stream.

## Sounds

UI sounds for moving around, selecting, going back, switching pages,
menus, toggles, launching, errors, applying a theme, and a start-up chime.
Each theme picks a pack: Dusk Tide uses `soft` (bells and marimba), Stylus
uses `chip` (square-wave bleeps), Dotfiles, Dotfiles Rain and Static
use `tty` (soft keyboard clacks). Turn them off in Start → Sounds.

The packs are synthesized from scratch by `tools/make-sounds.py`; edit it
and run `python3 tools/make-sounds.py` to regenerate them. Sounds need
`qt6-multimedia`.

## Themes

Press Start → Themes to switch theme. It applies right away; themes that
offer favourite colours also show a colour row, and themes with modes a
background row (down to reach them). Every built-in theme has several
backgrounds, including a pure black one (on the RP5's AMOLED screen, black
pixels are switched off, which saves power):

| Theme | Backgrounds (default first) |
| --- | --- |
| Dusk Tide, Dusk Tide Soft | dusk, night, dawn (light), black |
| Stylus | paper, cream, night, black |
| Dotfiles | dark, frost, ember, paper, black |
| Dotfiles Rain | paper, dark, amber |
| Static | dark, slate, paper, black |

Built in:

- **Dusk Tide**: teal dusk scene, peach accent, sharp corners
- **Dusk Tide Soft**: the same with round corners and Nunito
- **Stylus**: a retro handheld look with graph paper, true pixel type, chunky
  bevelled buttons and cartridge-shaped Library collections; pick any of
  16 colours
- **Dotfiles**: a terminal rice: JetBrains Mono everywhere, lowercase,
  `~/` page titles, numbered workspace tabs, a plain-text status line
  (`wifi on │ bat 78% │ 21:58`), a dot-grid wallpaper and a fetch-style
  system card on Home; pick from 8 terminal colours
- **Dotfiles Rain**: Dotfiles turned up: green phosphor on black, animated
  falling code behind everything (in your accent colour, three depths,
  flickering glyphs), CRT scanlines and a blinking block cursor. The rain
  pauses whenever an app or game is in front
- **Static**: a modern tiling-window-manager rice. Home is a set of tiled
  terminal windows (fetch, now playing, toggles, dock, a pipes screensaver
  and an audio visualizer from [cava](https://github.com/karlstav/cava));
  the bar has workspace numbers on the left, what's playing in the middle
  and cpu, memory, Wi-Fi, battery and time on the right. Behind it all: a
  greyscale photocopied-poster collage with a light drizzle of falling
  glyphs. Lavender by default, 8 colours to pick from. The pipes and cava
  tiles have a pause button in their title bar (tap it, or reach it with
  the d-pad) to save power; the choice is remembered
  The fetch card's picture starts as the handheld; tap it to go to the next of three:
  the handheld drawing, a dancing chibi girl (pixel art in half-block
  text, `tools/make-dancer.py`) and a headphone girl portrait in hi-fi
  ASCII line art that blinks now and then (`tools/make-portrait.py`
  draws her and matches characters to the drawing)

### Making a theme

A theme is a folder with a `theme.json`. Put it in
`~/.local/share/pocket-shell/themes/<folder-name>/` and it shows up in the
picker (a folder with the same name as a built-in theme replaces it).
Themes are data only: they choose colours, fonts and built-in styles, but
can't run code.

Every key is optional; anything missing falls back to Dusk Tide. A small
theme can be just:

```json
{
  "name": "Night Shift",
  "colors": { "accent": "#8FC8F2" },
  "accentChoices": ["#8FC8F2", "#F28B8B", "#9FE0C9"]
}
```

All keys:

| Key | What it sets |
| --- | --- |
| `name`, `description`, `author` | Shown in the picker |
| `colors` | `bg`, `surface`, `surfaceStrong`, `surfaceBorder`, `chip`, `chipFocused`, `focusGap`, `keyBorder`, `line`, `textStrong`, `text`, `textMuted`, `textHint`, `iconOnChip`, `accent`, `inkDark` / `inkLight` (text on the accent; picked by its brightness), `dim` (behind pages other than Home), `scrim` (behind menus), `ledge` (bevel shadow), `bar` / `barBorder` (top bar), `scanline` (style.scanlines). Colours can be `#RGB`, `#RRGGBB`, `#AARRGGBB`, `rgb(…)` or `rgba(…)` |
| `accentChoices` | Favourite colours offered in the picker |
| `modes` | Variants picked in the Background row, as a list: `[ { "id": "dark", "label": "dark" }, { "id": "paper", "colors": {…}, "wallpaper": {…} } ]`. Each mode overrides any keys it lists (`colors`, `wallpaper`, `accentChoices`, `cardColors`, `fonts`, `style`…); the first is usually the theme as written. The pick and the favourite colour are saved per theme and mode |
| `defaultMode` | The mode used until you pick one (else the first) |
| `cardColors` | Colours for Library collections and game cards (keep them dark enough for white text) |
| `radii` | Corner radii in px: `card`, `art`, `pill`, `btn`, `icon`, `dock`, `key` |
| `fonts` | `display`, `body` (font family names), `files` (font files in the theme folder to load), and for pixel fonts `displayGrid` (the font's pixel size at 1x, e.g. `8` for an 8×8 font) and `displayScale` (shrinks display text for wide fonts). With `displayGrid` set, display text snaps to whole multiples of the grid and isn't smoothed or fake-bolded, so it stays crisp |
| `focus` | Focus ring: `gap` and `ring` widths in px |
| `wallpaper` | `{ "type": "scene", "sky": [3 colours], "hills": [4 colours], "star" }` (Dusk Tide; colours optional), `{ "type": "grid", "color", "line", "size" }`, `{ "type": "dots", "color", "dot", "size" }`, `{ "type": "rain", "color", "glyph", "head", "size", "density", "speed" }` (falling code; `glyph` defaults to the accent; give a dark `head` on light backgrounds), `{ "type": "collage", "color", "ink", "seed", "words": [...] }` (poster collage, the same for a given seed), `{ "type": "color", "color" }` or `{ "type": "image", "file": "wallpaper.png" }` |
| `wallpaper.rain` | Any wallpaper can add light falling code on top: `{ "glyph", "head", "size", "density", "speed" }` |
| `sounds` | `"soft"`, `"chip"`, `"tty"`, `"none"`, or `"./folder"` with your own 48 kHz WAVs named `move`, `select`, `back`, `page`, `page-prev`, `page-next`, `open`, `toggle-on`, `toggle-off`, `launch`, `error`, `notice`, `theme`, `boot` |
| `style.border` | Panel border width |
| `style.bevel` | `true` for chunky buttons with a bottom ledge |
| `style.squareIcons` | `true` for square line ends (pixel look) |
| `style.keys` | Button hints: `"outline"` or `"filled"` |
| `style.tabs` | Page tabs: `"segmented"`, `"buttons"` or `"workspaces"` (numbered, with `user@host` on the left) or `"numbers"` (just numbers; the current page opens up to show its name) |
| `style.status` | Wi-Fi and battery: `"icons"`, `"pixel"`, `"text"`, or `"stats"` (a tiling-WM bar: tabs on the left, what's playing in the middle, cpu/mem/Wi-Fi/battery/time on the right) |
| `style.cards` | Library collections: `"card"` or `"cartridge"` |
| `style.home` | Home layout: `"classic"`, `"panels"` or `"fetch"` (system info card) or `"tiles"` (tiled terminal windows with pipes and a visualizer) |
| `style.textCase` | `"lower"` to lowercase labels and titles, or `"normal"` |
| `style.fetchLogo` | Fetch card picture: `"handheld"`, `"dancer"` or `"portrait"` (tap it to switch) |
| `style.titlePrefix` | Text drawn in the accent before page titles, e.g. `"~/"` |
| `style.cursor` | `true` for a blinking block cursor after page titles |
| `style.scanlines` | `true` for faint CRT lines over the whole screen |

The theme folder can hold its own fonts (list them in `fonts.files`) and
wallpaper image. Pocket Shell reloads a theme when its `theme.json` changes,
so you can edit it live.

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
  [JetBrains Mono](https://github.com/JetBrains/JetBrainsMono),
  [Manrope](https://github.com/googlefonts/manrope),
  [Nunito](https://github.com/googlefonts/nunito) and
  [Press Start 2P](https://github.com/google/fonts/tree/main/ofl/pressstart2p), by their project
  authors, under the SIL Open Font License 1.1
