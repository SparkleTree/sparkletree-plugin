#!/bin/sh
# PostToolUse for the SparkleTree tools that start paid async jobs
# (generate_campaign, render_video, video_commission create). Records when this
# session last started one, so spend-guard.sh can warn before a second start
# while the first may still be running. No output; always exits 0.
input=$(cat | tr -d '\n')
data=${1:-${CLAUDE_PLUGIN_DATA:-}}
[ -n "$data" ] || data="${TMPDIR:-/tmp}/sparkletree-plugin"
field() { printf '%s' "$input" | sed -n 's/.*"'"$1"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | tr -cd 'A-Za-z0-9_-'; }
tool=$(field tool_name); suffix=${tool##*__}
session=$(printf '%s' "$input" | sed -n 's/^.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*$/\1/p' | tr -cd 'A-Za-z0-9_-')
[ -n "$session" ] || session=nosession
case "$suffix" in
  generate_campaign|render_video) ;;
  video_commission) printf '%s' "$input" | grep -q '"action"[[:space:]]*:[[:space:]]*"create"' || exit 0 ;;
  *) exit 0 ;;
esac
# An error envelope started nothing.
printf '%s' "$input" | grep -q '\\\{0,1\}"error\\\{0,1\}"[[:space:]]*:[[:space:]]*{' && exit 0
mkdir -p "$data/jobs" 2>/dev/null && date +%s > "$data/jobs/$session-$suffix" 2>/dev/null
# Markers older than a day are no use to anyone.
find "$data/jobs" "$data/confirm" -type f -mmin +1440 -exec rm -f {} + 2>/dev/null
exit 0
