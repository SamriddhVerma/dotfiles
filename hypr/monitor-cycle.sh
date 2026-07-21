#!/usr/bin/env bash
# Cycle external monitor layout modes in Hyprland.
# Order: screen-only -> duplicate -> extend-left -> extend-right -> monitor-only -> (loop)
#
# "screen-only"  : internal display on, external off
# "duplicate"    : external mirrors the internal display
# "extend-left"  : external placed to the LEFT of the internal display
# "extend-right" : external placed to the RIGHT of the internal display
# "monitor-only" : external on, internal off

set -euo pipefail

STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/hypr-monitor-mode"

# Detect all connected monitors (including disabled ones).
mapfile -t MONS < <(hyprctl monitors all | awk '/^Monitor / {print $2}')

# Pick the internal panel (eDP/LVDS/DSI) and the first external one.
INTERNAL=""
EXTERNAL=""
for m in "${MONS[@]}"; do
	if [[ -z "$INTERNAL" && "$m" =~ ^(eDP|LVDS|DSI) ]]; then
		INTERNAL="$m"
	elif [[ -z "$EXTERNAL" && ! "$m" =~ ^(eDP|LVDS|DSI) ]]; then
		EXTERNAL="$m"
	fi
done

# Fallbacks if naming is unusual: just use the first two monitors found.
if [[ -z "$INTERNAL" && ${#MONS[@]} -ge 1 ]]; then INTERNAL="${MONS[0]}"; fi
if [[ -z "$EXTERNAL" && ${#MONS[@]} -ge 2 ]]; then
	for m in "${MONS[@]}"; do
		[[ "$m" != "$INTERNAL" ]] && EXTERNAL="$m" && break
	done
fi

notify() {
	command -v notify-send >/dev/null 2>&1 && notify-send -t 1500 "Display" "$1" || true
}

# Apply a monitor config via the Lua parser (hyprctl keyword is unsupported there).
mon_enable() { # output, position
	hyprctl eval "hl.monitor({ output = \"$1\", mode = \"preferred\", position = \"$2\", scale = 1, disabled = false, mirror = \"none\" })"
}
mon_mirror() { # output, mirror_of
	hyprctl eval "hl.monitor({ output = \"$1\", mode = \"preferred\", position = \"auto\", scale = 1, disabled = false, mirror = \"$2\" })"
}
mon_disable() { # output
	hyprctl eval "hl.monitor({ output = \"$1\", disabled = true })"
}

# No external monitor connected: force internal-only and reset state.
if [[ -z "$EXTERNAL" ]]; then
	[[ -n "$INTERNAL" ]] && mon_enable "$INTERNAL" "auto"
	echo 0 >"$STATE_FILE"
	notify "Screen only (no external monitor)"
	exit 0
fi

# Read + advance the cycle index.
MODE=0
[[ -f "$STATE_FILE" ]] && MODE=$(<"$STATE_FILE")
MODE=$(((MODE + 1) % 5))
echo "$MODE" >"$STATE_FILE"

case "$MODE" in
0) # screen only
	mon_enable "$INTERNAL" "auto"
	mon_disable "$EXTERNAL"
	notify "Screen only"
	;;
1) # duplicate / mirror
	mon_enable "$INTERNAL" "auto"
	mon_mirror "$EXTERNAL" "$INTERNAL"
	notify "Duplicate"
	;;
2) # extend left (external to the left of internal)
	mon_enable "$INTERNAL" "auto"
	mon_enable "$EXTERNAL" "auto-left"
	notify "Extend left"
	;;
3) # extend right (external to the right of internal)
	mon_enable "$INTERNAL" "auto"
	mon_enable "$EXTERNAL" "auto-right"
	notify "Extend right"
	;;
4) # monitor only (external on, internal off)
	mon_enable "$EXTERNAL" "auto"
	mon_disable "$INTERNAL"
	notify "Monitor only"
	;;
esac

# Safety net: if the wallpaper or bar process died during the output
# toggling, respawn it. Both normally survive (their surfaces are
# recreated automatically once a monitor returns), this just guards
# against an actual crash so the desktop always comes back.
sleep 0.3
if ! pgrep -x mpvpaper >/dev/null 2>&1; then
	hyprctl dispatch 'hl.dsp.exec_cmd([[prime-run mpvpaper -o "no-audio --loop" "*" /opt/shared-configs/wallpaper.jpg]])' >/dev/null 2>&1
fi
if ! pgrep -x qs >/dev/null 2>&1; then
	hyprctl dispatch 'hl.dsp.exec_cmd([[qs]])' >/dev/null 2>&1
fi
