#!/usr/bin/env bash

set -e

# plasmashell is not necessarily managed by systemd. When the unit is disabled
# and the session launches plasmashell directly (the default here), a
# `systemctl --user restart plasma-plasmashell` starts a *second* instance that
# exits at once on the single-instance guard: the running shell never reloads,
# so new QML is never picked up. Verified 2026-08-07 — the unit was
# inactive/disabled while plasmashell was running normally.
restart_plasmashell() {
    if systemctl --user is-active --quiet plasma-plasmashell.service; then
        systemctl --user restart plasma-plasmashell.service
    elif pgrep -x plasmashell >/dev/null 2>&1; then
        # --replace takes the DBus name over from the running instance, which
        # is the only thing that actually reloads the QML here.
        setsid plasmashell --replace >/dev/null 2>&1 &
        sleep 3
    else
        echo "  plasmashell isn't running — it will pick this up at login."
    fi
}

PLUGIN_ID="com.guti.codeprojects"
INSTALL_DIR="$HOME/.local/share/plasma/plasmoids/$PLUGIN_ID"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

MODE="${1:-install}"

case "$MODE" in
    install|link) ;;
    *)
        echo "Usage: $0 [install|link]"
        echo "  install  Copy the widget into place (default)"
        echo "  link     Symlink this checkout into place, for development"
        exit 1
        ;;
esac

echo "Installing Code Projects widget..."

if ! pacman -Qi plasma5support &>/dev/null; then
    echo "Installing plasma5support (required for Docker Compose buttons)..."
    sudo pacman -S --needed --noconfirm plasma5support
fi

if ! command -v konsole &>/dev/null; then
    echo "Installing konsole (required for Docker logs)..."
    sudo pacman -S --needed --noconfirm konsole
fi

# Resolved paths, not a string compare: a dev checkout is symlinked into place,
# and the literal test missed that. The copy branch would then see a directory
# (-d follows the link), delete the symlink and leave a stale copy where the
# link used to be, silently undoing the dev setup.
if [ "$MODE" = "link" ]; then
    if [ "$(readlink -f "$INSTALL_DIR" 2>/dev/null)" = "$SCRIPT_DIR" ]; then
        echo "Already linked to this checkout."
    else
        # -e is false for a dangling symlink, so test -L as well or a broken
        # link would survive and ln would fail on it.
        if [ -e "$INSTALL_DIR" ] || [ -L "$INSTALL_DIR" ]; then
            echo "Replacing $INSTALL_DIR..."
            rm -rf "$INSTALL_DIR"
        fi
        mkdir -p "$(dirname "$INSTALL_DIR")"
        ln -s "$SCRIPT_DIR" "$INSTALL_DIR"
        echo "Linked $INSTALL_DIR -> $SCRIPT_DIR"
    fi
elif [ "$(readlink -f "$INSTALL_DIR" 2>/dev/null)" = "$SCRIPT_DIR" ]; then
    echo "Install path already resolves to this checkout, skipping copy."
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
restart_plasmashell
echo ""
echo "Done! Add the widget to your panel:"
echo "  Right-click panel → Add Widgets → search 'Code Projects'"
