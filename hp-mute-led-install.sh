#!/usr/bin/env bash
#
# Installer for the HP Victus mute-LED sync.
#
#   Run it with root:   sudo bash hp-mute-led-install.sh
#
# It installs:
#   /usr/local/bin/hp-mute-led            root helper that toggles the LED
#   /usr/local/bin/hp-mute-led-watch      per-user monitor of the mute state
#   /etc/systemd/user/hp-mute-led.service user service that runs the monitor
#   /etc/sudoers.d/hp-mute-led            lets the monitor call the helper
#
# Uninstall:  sudo bash hp-mute-led-install.sh --uninstall
#
set -euo pipefail

BIN_DIR="${BIN_DIR:-/usr/local/bin}"
UNIT_DIR="${UNIT_DIR:-/etc/systemd/user}"
SUDOERS_DIR="${SUDOERS_DIR:-/etc/sudoers.d}"
DO_SYSTEM="${DO_SYSTEM:-1}"   # set 0 for a no-root dry run into custom dirs

HELPER="$BIN_DIR/hp-mute-led"
WATCH="$BIN_DIR/hp-mute-led-watch"
UNIT="$UNIT_DIR/hp-mute-led.service"
SUDOERS="$SUDOERS_DIR/hp-mute-led"

if [ "${1:-}" = "--uninstall" ]; then
    if [ "$DO_SYSTEM" = 1 ]; then
        systemctl --global disable hp-mute-led.service 2>/dev/null || true
    fi
    rm -f "$HELPER" "$WATCH" "$UNIT" "$SUDOERS"
    [ "$DO_SYSTEM" = 1 ] && systemctl daemon-reload 2>/dev/null || true
    echo "Removed. Run 'systemctl --user disable --now hp-mute-led.service' in each user session."
    exit 0
fi

if [ "$DO_SYSTEM" = 1 ] && [ "$(id -u)" -ne 0 ]; then
    echo "This installer must run as root:  sudo bash $0" >&2
    exit 1
fi

if [ "$DO_SYSTEM" = 1 ] && ! command -v hda-verb >/dev/null 2>&1; then
    echo "hda-verb not found (install the 'alsa-tools' package first)." >&2
    exit 1
fi

mkdir -p "$BIN_DIR" "$UNIT_DIR" "$SUDOERS_DIR"

# ---------------------------------------------------------------- root helper
cat > "$HELPER" <<'HELPER_EOF'
#!/usr/bin/env bash
# Toggle the HP Victus (Realtek ALC245) mute-key status LED.
#   hp-mute-led on    -> LED lit   (audio muted)
#   hp-mute-led off   -> LED dark  (audio not muted)
# Must run as root: the HDA hwdep interface requires it.
set -euo pipefail

case "${1:-}" in
    on)  val=0x8 ;;
    off) val=0x0 ;;
    *)   echo "usage: ${0##*/} on|off" >&2; exit 2 ;;
esac

HDA_VERB=/usr/bin/hda-verb

# Find the Realtek codec's hwdep node (robust if card numbers change).
dev=""
for codec in /proc/asound/card*/codec#*; do
    [ -e "$codec" ] || continue
    if grep -qi "Realtek" "$codec"; then
        card="${codec%/codec#*}"
        idx="${card##*card}"
        cn="${codec##*#}"
        cand="/dev/snd/hwC${idx}D${cn}"
        if [ -e "$cand" ]; then dev="$cand"; break; fi
    fi
done
[ -n "$dev" ] || dev="/dev/snd/hwC1D0"

# Select processing-coefficient index 0x0B on the vendor widget (node 0x20),
# then write the LED value.
"$HDA_VERB" "$dev" 0x20 0x500 0x0B >/dev/null
"$HDA_VERB" "$dev" 0x20 0x400 "$val" >/dev/null
HELPER_EOF
chmod 0755 "$HELPER"

# --------------------------------------------------------------- watch script
cat > "$WATCH" <<'WATCH_EOF'
#!/usr/bin/env bash
# Per-user monitor: mirror the default sink's mute state onto the mute LED.
# Runs as the logged-in user; drives the LED through the sudo helper.
set -u

HELPER="/usr/local/bin/hp-mute-led"
last=""

desired_state() {
    if pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null | grep -qi 'yes'; then
        echo on
    else
        echo off
    fi
}

sync_led() {
    local d
    d="$(desired_state)"
    if [ "$d" != "$last" ]; then
        if sudo -n "$HELPER" "$d" >/dev/null 2>&1; then
            last="$d"
        fi
    fi
}

while true; do
    # Wait until the audio server is reachable.
    if ! pactl info >/dev/null 2>&1; then
        sleep 5
        continue
    fi

    last=""        # force an initial push after (re)connecting
    sync_led

    # React to mute changes and default-sink changes.
    while read -r line; do
        case "$line" in
            *"on sink"*|*"on server"*) sync_led ;;
        esac
    done < <(pactl subscribe 2>/dev/null)

    sleep 2        # subscribe ended (server restart?), reconnect
done
WATCH_EOF
chmod 0755 "$WATCH"

# ------------------------------------------------------------------ user unit
cat > "$UNIT" <<'UNIT_EOF'
[Unit]
Description=HP Victus mute LED synchronisation
After=pipewire-pulse.service pipewire.service
Wants=pipewire-pulse.service

[Service]
Type=simple
ExecStart=/usr/local/bin/hp-mute-led-watch
Restart=on-failure
RestartSec=3

[Install]
WantedBy=default.target
UNIT_EOF
chmod 0644 "$UNIT"

# -------------------------------------------------------------------- sudoers
umask 077
cat > "$SUDOERS" <<'SUDOERS_EOF'
# Let any local user drive the HP Victus mute LED. The command is fixed and
# the only accepted arguments are "on" and "off", so this is safe.
ALL ALL=(root) NOPASSWD: /usr/local/bin/hp-mute-led on, /usr/local/bin/hp-mute-led off
SUDOERS_EOF
chmod 0440 "$SUDOERS"

if [ "$DO_SYSTEM" = 1 ]; then
    visudo -cf "$SUDOERS" >/dev/null
    systemctl daemon-reload || true
    systemctl --global enable hp-mute-led.service

    target_user="${SUDO_USER:-your-user}"
    echo
    echo "Installed successfully."
    echo
    echo "Start it now in the desktop session of '$target_user' (no root):"
    echo "    systemctl --user daemon-reload"
    echo "    systemctl --user enable --now hp-mute-led.service"
    echo
    echo "It also auto-starts for every user at their next login."
fi
