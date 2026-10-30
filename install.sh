#!/bin/bash
# Install Pocket Shell from this repo onto the device.
# User configs are symlinked so `git pull` updates them in place;
# the session launcher and session entry are copied (they need root).
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"

link() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    echo "ok       $dst"
    return
  fi
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    mv "$dst" "$dst.bak-$STAMP"
    echo "backup   $dst -> $dst.bak-$STAMP"
  fi
  ln -s "$src" "$dst"
  echo "linked   $dst -> $src"
}

link "$REPO/hypr/hyprland.lua"     "$HOME/.config/hypr/hyprland.lua"
link "$REPO/quickshell"            "$HOME/.config/quickshell"
link "$REPO/fonts"                 "$HOME/.local/share/fonts/pocket-shell"
# "Pocket Shell" app for other desktops (Plasma Mobile): switches over
link "$REPO/session/pocket-shell.desktop" "$HOME/.local/share/applications/pocket-shell.desktop"
link "$REPO/session/pocket-shell.svg"     "$HOME/.local/share/icons/hicolor/scalable/apps/pocket-shell.svg"
# Gamepad Tester in the app lists (the program is built below)
link "$REPO/input/pocket-padtest.desktop" "$HOME/.local/share/applications/pocket-padtest.desktop"
# Plasma Mobile 6.8 builds its app drawer from the XDG menu; rebuilding the
# list without the plasma- menu prefix (as over SSH) leaves only Waydroid
MENU_PREFIX="${XDG_MENU_PREFIX:-}"
[ -z "$MENU_PREFIX" ] && [ -f /etc/xdg/menus/plasma-applications.menu ] && MENU_PREFIX=plasma-
command -v kbuildsycoca6 >/dev/null && XDG_MENU_PREFIX="$MENU_PREFIX" kbuildsycoca6 >/dev/null 2>&1 \
  && echo "apps     Plasma app list refreshed"

if command -v fc-cache >/dev/null; then
  fc-cache -f "$HOME/.local/share/fonts" >/dev/null && echo "fonts    cache refreshed"
fi

HELPER_OK=0
if command -v cc >/dev/null && command -v make >/dev/null && pkg-config --exists sdl3 2>/dev/null; then
  echo "Building controller helper..."
  make -s -C "$REPO/input"
  HELPER_OK=1
else
  echo "skipped  controller helper: needs gcc, make, pkgconf and sdl3"
  echo "         install them with: sudo pacman -S --needed gcc make pkgconf sdl3"
fi

echo "Installing system files (needs sudo)..."
sudo install -Dm755 "$REPO/session/pocketshell-session"  /usr/local/bin/pocketshell-session
sudo install -Dm644 "$REPO/session/pocketshell.desktop"  /usr/share/wayland-sessions/pocketshell.desktop
echo "installed /usr/local/bin/pocketshell-session"
echo "installed /usr/share/wayland-sessions/pocketshell.desktop"
sudo install -Dm755 "$REPO/bin/pocket-games" /usr/local/bin/pocket-games
echo "installed /usr/local/bin/pocket-games"
sudo install -Dm755 "$REPO/bin/pocket-play" /usr/local/bin/pocket-play
echo "installed /usr/local/bin/pocket-play"
# Back button profile, loaded by the session while Pocket Shell runs
sudo install -Dm755 "$REPO/bin/pocket-back" /usr/local/bin/pocket-back
sudo install -Dm644 "$REPO/input/back-button.yaml" /usr/local/share/pocket-shell/back-button.yaml
echo "installed /usr/local/bin/pocket-back"
sudo install -Dm755 "$REPO/bin/pocket-dock" /usr/local/bin/pocket-dock
echo "installed /usr/local/bin/pocket-dock"
sudo install -Dm755 "$REPO/bin/pocket-colors" /usr/local/bin/pocket-colors
echo "installed /usr/local/bin/pocket-colors"

# Charge limit: the helper, its saved setting (75% to start with; your group
# may change it) and a udev rule that applies it at every boot
sudo install -Dm755 "$REPO/bin/pocket-battery" /usr/local/bin/pocket-battery
if [ ! -f /etc/pocket-shell/charge-limit ]; then
  echo 75 | sudo install -Dm664 -g "$(id -gn)" /dev/stdin /etc/pocket-shell/charge-limit
else
  sudo chgrp "$(id -gn)" /etc/pocket-shell/charge-limit
  sudo chmod 664 /etc/pocket-shell/charge-limit
fi
sudo install -Dm644 "$REPO/system/90-pocket-battery.rules" /etc/udev/rules.d/90-pocket-battery.rules
sudo udevadm control --reload
# Apply it now as well, without waiting for a reboot
sudo /usr/local/bin/pocket-battery boot
if [ -n "$(/usr/local/bin/pocket-battery status | sed -n 's/^supported=1$/y/p')" ]; then
  echo "installed /usr/local/bin/pocket-battery (charge limit $(cat /etc/pocket-shell/charge-limit)%)"
else
  echo "installed /usr/local/bin/pocket-battery (this kernel has no charge limit yet; update pocknix)"
fi
if ! id -nG | grep -qwE 'wheel|inputplumber'; then
  echo "note     $USER isn't in the wheel or inputplumber group, so the Back"
  echo "         button profile can't load; Back falls back to Home + A"
fi
if [ "$HELPER_OK" = 1 ]; then
  sudo install -Dm755 "$REPO/input/pocket-input" /usr/local/bin/pocket-input
  echo "installed /usr/local/bin/pocket-input"
  sudo install -Dm755 "$REPO/input/pocket-padtest" /usr/local/bin/pocket-padtest
  echo "installed /usr/local/bin/pocket-padtest"
  # Stick range calibration (pocket-sticks calibrate), put back at every boot
  sudo install -Dm755 "$REPO/bin/pocket-sticks" /usr/local/bin/pocket-sticks
  sudo install -Dm644 "$REPO/system/91-pocket-sticks.rules" /etc/udev/rules.d/91-pocket-sticks.rules
  sudo udevadm control --reload
  echo "installed /usr/local/bin/pocket-sticks"
  # Lets Gamepad Tester's Calibrate screen read the hidden pad and save,
  # without a password (wheel group only); checked before it goes in
  if getent group wheel >/dev/null && sudo visudo -cqf "$REPO/system/pocket-shell-sticks.sudoers"; then
    sudo install -Dm440 "$REPO/system/pocket-shell-sticks.sudoers" /etc/sudoers.d/pocket-shell-sticks
    echo "installed /etc/sudoers.d/pocket-shell-sticks"
  fi
fi

# RetroArch: controller profiles (Arch's package ships none, so pads do
# nothing), minus the Guide button opening RetroArch's menu, since Home
# belongs to the shell. The Back button opens the menu instead (F1).
if command -v retroarch >/dev/null; then
  RA_AUTO="$HOME/.config/retroarch/autoconfig"
  RA_PAD="$RA_AUTO/udev/Microsoft X-Box 360 pad.cfg"
  if [ ! -f "$RA_PAD" ] && command -v git >/dev/null; then
    tmp="$(mktemp -d)"
    if git clone -q --depth 1 https://github.com/libretro/retroarch-joypad-autoconfig "$tmp/ra"; then
      mkdir -p "$RA_AUTO"
      cp -r "$tmp/ra/udev" "$tmp/ra/sdl2" "$RA_AUTO/"
      echo "installed RetroArch controller profiles"
    fi
    rm -rf "$tmp"
  fi
  if [ -f "$RA_PAD" ] && grep -q '^input_menu_toggle_btn' "$RA_PAD"; then
    sed -i '/^input_menu_toggle_btn/d' "$RA_PAD"
    echo "RetroArch: Guide/Home no longer opens its menu (use Back)"
  fi
fi

# Optional extras: the shell works without them, minus these features.
missing=()
command -v wpctl >/dev/null || missing+=("wireplumber (volume buttons)")
command -v brightnessctl >/dev/null || missing+=("brightnessctl (brightness)")
compgen -G "/usr/lib*/qt6/qml/QtMultimedia" >/dev/null || missing+=("qt6-multimedia (sounds)")
command -v cava >/dev/null || missing+=("cava (audio visualizer in the Static theme)")
command -v mpv >/dev/null || missing+=("mpv, mpv-mpris, yt-dlp (pocket-play)")
command -v plasmatube >/dev/null || missing+=("plasmatube (YouTube app for the Now Playing video button)")
command -v moonlight >/dev/null || missing+=("moonlight-qt (stream games from a PC)")
if [ ${#missing[@]} -gt 0 ]; then
  echo
  echo "Optional, not installed:"
  printf '  - %s\n' "${missing[@]}"
  echo "Install with: sudo pacman -S --needed wireplumber brightnessctl qt6-multimedia cava mpv mpv-mpris yt-dlp plasmatube moonlight-qt"
fi

echo
echo "Done. Switch with: pocknix-desktop-select pocketshell --now"
