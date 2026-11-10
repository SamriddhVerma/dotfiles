#!/usr/bin/env bash
# KDE Plasma (Wayland) equivalent of hypr/replay-buffer-record.sh.
# KWin has no wlr-screencopy, so wf-recorder can't be used here. Instead this
# runs gpu-screen-recorder in replay mode (portal capture + PipeWire audio),
# keeping the last 5 minutes in RAM until kde/save-replay.sh asks it to flush.

set -u

OUT_DIR="${REPLAY_OUT_DIR:-$HOME/Videos/replays}"
REPLAY_SECS=300
LOCK_FILE="${XDG_RUNTIME_DIR:-/tmp}/replay-buffer-record.lock"
PID_FILE="${XDG_RUNTIME_DIR:-/tmp}/replay-buffer-record.pid"
SAVED_HOOK="$(dirname "$(readlink -f "$0")")/replay-saved-notify.sh"

mkdir -p "$OUT_DIR"

exec 9>"$LOCK_FILE"
if ! flock -n 9; then
	echo "replay-buffer-record.sh already running, exiting."
	exit 0
fi

# The portal asks which screen to share the first time only; the restore
# token is stored so later logins start silently.
gpu-screen-recorder \
	-w portal \
	-restore-portal-session yes \
	-f 60 \
	-a default_output \
	-c mp4 \
	-r "$REPLAY_SECS" \
	-replay-storage ram \
	-sc "$SAVED_HOOK" \
	-o "$OUT_DIR" \
	>>/tmp/replay-buffer-record.log 2>&1 &

echo $! >"$PID_FILE"
wait $!
