#!/usr/bin/env bash
# Per-user setup for the KDE replay buffer: autostart + Meta+T shortcut.
# Requires: gpu-screen-recorder (sudo pacman -S gpu-screen-recorder)
set -eu

DIR="$(dirname "$(readlink -f "$0")")"

command -v gpu-screen-recorder >/dev/null \
	|| { echo "Install gpu-screen-recorder first: sudo pacman -S gpu-screen-recorder"; exit 1; }

chmod +x "$DIR"/*.sh
mkdir -p ~/.config/autostart ~/.local/share/applications

cat >~/.config/autostart/replay-buffer.desktop <<EOF
[Desktop Entry]
Type=Application
Name=Replay Buffer
Exec=$DIR/replay-buffer-record.sh
EOF

cat >~/.local/share/applications/save-replay.desktop <<EOF
[Desktop Entry]
Type=Application
Name=Save Replay (last 5 min)
Exec=$DIR/save-replay.sh
NoDisplay=true
X-KDE-GlobalAccel-CommandShortcut=true
EOF

kwriteconfig6 --file kglobalshortcutsrc --group services \
	--group save-replay.desktop --key _launch "Meta+T"

echo "Done. Log out/in (or run kde/replay-buffer-record.sh) to start recording."
