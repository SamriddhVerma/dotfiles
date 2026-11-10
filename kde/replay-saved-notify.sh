#!/usr/bin/env bash
# Called by gpu-screen-recorder after a replay is saved: $1 = file, $2 = type.
notify-send "Replay Buffer" "Saved last 5 min to $1"
