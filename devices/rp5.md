# Device profile: Retroid Pocket 5 (SM8250)

Tested on pocknix-os 0.4.0 (base 20260826.3), booted from microSD.

This is a notes file for now. It becomes a machine-readable profile that
both the Hyprland config and the shell read once the shell skeleton exists.

## Display

| Setting | Value |
| --- | --- |
| Output | `DSI-1` |
| Native mode | `1080x1920@60` (portrait panel, 68×121 mm) |
| Scale | `2` |
| Landscape transform | `1` (3 was tried first and is wrong on this unit) |
| Logical size, landscape | 960×540 |

- The panel's EDID doesn't parse, so `mode = "preferred"` only works if the
  panel is already lit. Always set the explicit mode.
- Touch must be bound to `DSI-1` with the same transform as the output.

## Session

- pocknix uses **seatd** (for gamescope). Plasma's KWin uses logind.
  Hyprland on default seatd works once KWin is gone.
- Plasma 6 runs KWin as a **systemd user service** that outlives pocknix's
  session switch by about 4 s. See the README write-up.
- plasmashell segfaults on every logout (visible in the journal). Likely
  harmless and unrelated.

## Input

- The built-in controls are `Retroid Pocket Gamepad`. pocknix runs
  **InputPlumber**, which hides it and presents a virtual
  `Microsoft X-Box 360 pad` (plus `InputPlumber Keyboard`) to apps. That's
  what SDL and `pocket-input` see.
- The touchscreen is `generic ft5x06 (a0)`.
- The RP5 has a gyroscope in hardware, but pocknix doesn't expose it yet: no
  IIO accelerometer/gyro and no motion input device show up. The virtual 360
  pad has no gyro either.
- InputPlumber has an *intercept mode* for routing input to an overlay instead
  of the game; a possible future way to keep the shell out of games.

## Useful pocknix commands

- `pocknix-desktop-select list | current | <name> [--now]`
- `steamos-session-select gamescope | plasma`
- `sudo pocknix-base rolling` / `sudo pocknix-base locked`, and `pocknix-rollback`
- Supervisor log: `~/pocknix-session.log`
- pocknix falls back to game mode if a desktop fails 3 times quickly.

## External display (USB-C)

- DisplayPort Alt Mode works on pocknix: a monitor shows up as `DP-1`
  (`/sys/class/drm/card0-DP-1/status`). Hyprland only lights it with a rule
  (`hyprctl eval 'hl.monitor({ output = "DP-1", disabled = false, ... })'`).
- DisplayPort audio works but isn't in pocknix's UCM profile. Route
  `DISPLAY_PORT_RX Audio Mixer MultiMedia3` on (look it up by name: numids
  differ between `-c0` and `-D hw:0`) and play on `hw:0,2`, 48 kHz S16_LE
  stereo. Without the route, opening the PCM fails with EINVAL. Reopening it
  right after closing once failed with "Connection timed out".
- Jack control: `DP0 Jack` (iface=CARD).

