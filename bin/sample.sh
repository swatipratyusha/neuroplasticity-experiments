#!/bin/zsh
# Passive telemetry sampler — one CSV row per invocation (launchd, every 60s).
# Columns: ts,idle_s,front_app,front_title,agent_procs,active_transcripts,docker_containers
set -u
export PATH="/usr/local/bin:/opt/homebrew/bin:${PATH:-/usr/bin:/bin:/usr/sbin:/sbin}"  # launchd PATH lacks docker
. "${0:A:h}/common.sh"
DIR="$DATA/telemetry"
OUT="$DIR/$(date +%F).csv"
mkdir -p "$DIR"
[ -f "$OUT" ] || echo "ts,idle_s,front_app,front_title,agent_procs,active_transcripts,docker_containers" > "$OUT"

TS=$(date +%FT%T)
IDLE=$(idle_seconds)

FRONT=$(osascript -e '
tell application "System Events"
  set p to first application process whose frontmost is true
  set appName to name of p
  try
    set winName to name of front window of p
  on error
    set winName to ""
  end try
end tell
return appName & "|~|" & winName' 2>/dev/null)
# Distinguish TCC/automation denial from a genuine empty title — a permission
# revocation must not masquerade as data.
[ -z "$FRONT" ] && FRONT="TCC_DENIED|~|"
APP=${FRONT%%|~|*}
TITLE=${FRONT#*|~|}
# System Events can't read iTerm2 window names; ask iTerm2 directly (the tab
# title identifies which agent session is on screen).
if [ "$APP" = "iTerm2" ] && [ -z "$TITLE" ]; then
  TITLE=$(osascript -e 'tell application "iTerm2" to get name of current window' 2>/dev/null)
fi

AGENT_PROCS=$(pgrep -fl "$SAMPLE_AGENT_PROC_MATCH" | grep -c "$SAMPLE_AGENT_PROC_MATCH " || true)
ACTIVE_TX=$(find "$SAMPLE_TRANSCRIPT_DIR" -name "*.jsonl" -mmin -2 2>/dev/null | wc -l | tr -d ' ')
if [ "$SAMPLE_TRACK_DOCKER" = "1" ]; then
  DOCKERS=$( (command -v docker >/dev/null && docker ps -q 2>/dev/null || true) | grep -c . || true)
else
  DOCKERS=""
fi

esc() { printf '"%s"' "${1//\"/\"\"}"; }
echo "$TS,$IDLE,$(esc "$APP"),$(esc "$TITLE"),$AGENT_PROCS,$ACTIVE_TX,$DOCKERS" >> "$OUT"
