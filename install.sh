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

echo "Installing session files (needs sudo)..."
sudo install -Dm755 "$REPO/session/pocketshell-session"  /usr/local/bin/pocketshell-session
sudo install -Dm644 "$REPO/session/pocketshell.desktop"  /usr/share/wayland-sessions/pocketshell.desktop
echo "installed /usr/local/bin/pocketshell-session"
echo "installed /usr/share/wayland-sessions/pocketshell.desktop"

echo
echo "Done. Switch with: pocknix-desktop-select pocketshell --now"
