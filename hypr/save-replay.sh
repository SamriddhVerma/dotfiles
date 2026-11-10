#!/usr/bin/env bash
# Saves the last ~5 minutes from the rolling replay buffer to a file.
# Bound to SUPER + T in Hyprland.

set -u

BUFFER_DIR="${REPLAY_BUFFER_DIR:-$HOME/.cache/replay-buffer}"
OUT_DIR="$HOME/Videos/replays"
SAVE_SECONDS=300     # 5 minutes
SEGMENT_SECS=10
SEGMENTS_NEEDED=$(( (SAVE_SECONDS / SEGMENT_SECS) + 2 )) # small safety margin

mkdir -p "$OUT_DIR"

notify() {
	notify-send "Replay Buffer" "$1"
}

mapfile -t files < <(find "$BUFFER_DIR" -maxdepth 1 -name 'seg-*.mp4' -printf '%T@ %p\n' 2>/dev/null \
	| sort -n | tail -n "$SEGMENTS_NEEDED" | cut -d' ' -f2-)

if [ "${#files[@]}" -eq 0 ]; then
	notify "No footage buffered yet, try again in a few seconds."
	exit 1
fi

ts=$(date +%Y%m%d-%H%M%S)
list_file=$(mktemp /tmp/replay-list-XXXXXX.txt)
concat_tmp="$OUT_DIR/.replay-$ts-concat.mp4"
out_file="$OUT_DIR/replay-$ts.mp4"

for f in "${files[@]}"; do
	printf "file '%s'\n" "$f" >>"$list_file"
done

if ! ffmpeg -y -f concat -safe 0 -i "$list_file" -c copy "$concat_tmp" \
	>/tmp/replay-save.log 2>&1; then
	rm -f "$list_file" "$concat_tmp"
	notify "Failed to save replay - see /tmp/replay-save.log"
	exit 1
fi
rm -f "$list_file"

# Trim to the exact last SAVE_SECONDS worth of footage.
duration=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$concat_tmp" 2>/dev/null)
duration=${duration%.*}
if [ -n "$duration" ] && [ "$duration" -gt "$SAVE_SECONDS" ]; then
	start=$((duration - SAVE_SECONDS))
	ffmpeg -y -ss "$start" -i "$concat_tmp" -c copy "$out_file" >>/tmp/replay-save.log 2>&1
	rm -f "$concat_tmp"
else
	mv "$concat_tmp" "$out_file"
fi

if [ -s "$out_file" ]; then
	notify "Saved last 5 min to $out_file"
else
	notify "Failed to save replay - see /tmp/replay-save.log"
	exit 1
fi
