#!/usr/bin/env bash
# Continuously records the screen (+ audio) in short rolling segments so that
# the last N minutes are always available to be saved on demand.
# Uses wf-recorder (wlr-screencopy) directly - no xdg-desktop-portal needed,
# works natively under Hyprland/Wayland.

set -u

BUFFER_DIR="${REPLAY_BUFFER_DIR:-$HOME/.cache/replay-buffer}"
SEGMENT_SECS=10          # length of each rolling segment
BUFFER_MINUTES=6         # keep a little more than the 5 min we actually save
LOCK_FILE="/tmp/replay-buffer-record.lock"

mkdir -p "$BUFFER_DIR"

exec 9>"$LOCK_FILE"
if ! flock -n 9; then
	echo "replay-buffer-record.sh already running, exiting."
	exit 0
fi

cleanup_old() {
	find "$BUFFER_DIR" -maxdepth 1 -name 'seg-*.mp4' -mmin "+${BUFFER_MINUTES}" -delete
}

term_handler() {
	kill -TERM "$child_pid" 2>/dev/null
	wait "$child_pid" 2>/dev/null
	exit 0
}
trap term_handler SIGTERM SIGINT

while true; do
	ts=$(date +%Y%m%d-%H%M%S-%N)
	out="$BUFFER_DIR/seg-$ts.mp4"

	wf-recorder \
		-f "$out" \
		--audio \
		-c libx264 \
		-p preset=veryfast \
		-p crf=18 \
		-p bf=0 \
		>>/tmp/replay-buffer-record.log 2>&1 &
	child_pid=$!

	sleep "$SEGMENT_SECS"

	kill -INT "$child_pid" 2>/dev/null
	wait "$child_pid" 2>/dev/null

	cleanup_old
done
