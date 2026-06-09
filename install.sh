#!/usr/bin/env bash

set -e

PLUGIN_ID="com.guti.codeprojects"
INSTALL_DIR="$HOME/.local/share/plasma/plasmoids/$PLUGIN_ID"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Installing Code Projects widget..."

if ! pacman -Qi plasma5support &>/dev/null; then
    echo "Installing plasma5support (required for Docker Compose buttons)..."
    sudo pacman -S --needed --noconfirm plasma5support
fi

if ! command -v konsole &>/dev/null; then
    echo "Installing konsole (required for Docker logs)..."
    sudo pacman -S --needed --noconfirm konsole
fi

if [ "$SCRIPT_DIR" = "$INSTALL_DIR" ]; then
    echo "Already running from install location, skipping copy."
else
    if [ -d "$INSTALL_DIR" ]; then
        echo "Removing previous installation..."
        rm -rf "$INSTALL_DIR"
    fi

    echo "Copying files to $INSTALL_DIR..."
    mkdir -p "$INSTALL_DIR"
    cp -r "$SCRIPT_DIR/contents" "$INSTALL_DIR/"
    cp "$SCRIPT_DIR/metadata.json" "$INSTALL_DIR/"
fi

echo "Restarting Plasma shell..."
systemctl --user restart plasma-plasmashell

echo ""
echo "Done! Add the widget to your panel:"
echo "  Right-click panel → Add Widgets → search 'Code Projects'"
