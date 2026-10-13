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
if [ "$HELPER_OK" = 1 ]; then
  sudo install -Dm755 "$REPO/input/pocket-input" /usr/local/bin/pocket-input
  echo "installed /usr/local/bin/pocket-input"
fi

# Optional extras: the shell works without them, minus these features.
missing=()
command -v wpctl >/dev/null || missing+=("wireplumber (volume buttons)")
command -v brightnessctl >/dev/null || missing+=("brightnessctl (brightness)")
compgen -G "/usr/lib*/qt6/qml/QtMultimedia" >/dev/null || missing+=("qt6-multimedia (sounds)")
if [ ${#missing[@]} -gt 0 ]; then
  echo
  echo "Optional, not installed:"
  printf '  - %s\n' "${missing[@]}"
  echo "Install with: sudo pacman -S --needed wireplumber brightnessctl qt6-multimedia"
fi

echo
echo "Done. Switch with: pocknix-desktop-select pocketshell --now"
