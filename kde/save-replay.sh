#!/usr/bin/env bash
# Flushes the last 5 minutes from the running gpu-screen-recorder replay buffer.
# Bound to Meta + T in KDE Plasma (see kde/install.sh).

PID_FILE="${XDG_RUNTIME_DIR:-/tmp}/replay-buffer-record.pid"

if [ -r "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
	# gpu-screen-recorder saves the replay on SIGUSR1
	kill -USR1 "$(cat "$PID_FILE")"
else
	notify-send "Replay Buffer" "Recorder isn't running. Start kde/replay-buffer-record.sh first."
	exit 1
fi
