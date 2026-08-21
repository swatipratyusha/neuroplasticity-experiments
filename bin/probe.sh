#!/bin/zsh
# Subjective focus probe — experience sampling by dialog.
# launchd fires it on the hour across your working window; it then fires
# probabilistically after a random in-hour delay, so a handful of samples land
# at times you cannot anticipate. Skips when you are away or the cap is met.
# Stores ts + raw answer only; parsing happens at analysis time (free-form
# answers do not survive rigid field splitting).
set -u
export PATH="${PATH:-/usr/bin:/bin:/usr/sbin:/sbin}"
. "${0:A:h}/common.sh"
OUT="$DATA/probes.csv"
LOCK="$DATA/.probe.lock"
mkdir -p "$DATA"
[ -f "$OUT" ] || echo "ts,raw" > "$OUT"

# Only real answers count toward the daily cap. A gave-up dialog returns empty
# text with rc=0, so "(empty)" rows are timeouts too, not just failures.
cap_reached() { [ "$(grep "^$(date +%F)" "$OUT" | grep -vcE "probe-failed|\(empty\)" || true)" -ge "$PROBE_DAILY_CAP" ]; }
note() { echo "$(date +%FT%T) $1" >> "$DATA/probe_runs.log"; }
cap_reached && { note skip-cap; exit 0; }

IDLE=$(idle_seconds)
[ "${IDLE:-99999}" -gt "$PROBE_IDLE_SKIP_S" ] && { note "skip-idle ${IDLE}s"; exit 0; }

# Guarantee at least one late-day sample: if nothing has fired since 18:00,
# skip the probability gate once the evening hour arrives.
evening_uncovered() {
  [ "$(date +%H)" -ge "$PROBE_EVENING_HOUR" ] && ! grep -q "^$(date +%F)T\(1[89]\|2[0-9]\):.* firing" "$DATA/probe_runs.log" 2>/dev/null
}
if [ "${FORCE:-0}" != "1" ]; then          # FORCE=1 bypasses gate + delay for smoke tests
  if evening_uncovered; then
    note firing-stratified
    sleep $((RANDOM % 600))
  else
    [ $((RANDOM % 100)) -ge "$PROBE_FIRE_PCT" ] && { note skip-gate; exit 0; }
    note firing          # logged before the delay: a probe asleep in its delay
    sleep $((RANDOM % PROBE_MAX_DELAY_S))   # must still count as covering its slot
  fi
else
  note firing
fi

# One dialog at a time — a stale lock (>10 min) is reclaimed
if ! mkdir "$LOCK" 2>/dev/null; then
  find "$LOCK" -maxdepth 0 -mmin +10 -exec rmdir {} \; 2>/dev/null
  mkdir "$LOCK" 2>/dev/null || { note skip-locked; exit 0; }
fi
trap 'rmdir "$LOCK" 2>/dev/null' EXIT
cap_reached && exit 0              # authoritative cap check, held under the lock

TS=$(date +%FT%T)
afplay /System/Library/Sounds/Glass.aiff 2>/dev/null &
# Activate System Events first so the dialog comes frontmost — background
# dialogs otherwise sit behind full-screen windows, unseen.
# Keep stderr: "User canceled"/gave-up is a dismissal, -1743 etc. is TCC denial.
RAW_OUT=$(osascript -e "tell application \"System Events\"
activate
text returned of (display dialog \"Focus check 🧠
${PROBE_QUESTION//\"/\\\"}\" default answer \"\" with title \"Neuroplasticity probe\" giving up after $PROBE_TIMEOUT_S)
end tell" 2>&1)
RC=$?
if [ $RC -ne 0 ]; then
  ANSWER="(probe-failed rc=$RC: ${RAW_OUT:0:80})"
elif [ -z "$RAW_OUT" ]; then
  ANSWER="(empty)"
else
  ANSWER="$RAW_OUT"
fi
printf '%s,"%s"\n' "$TS" "${ANSWER//\"/\"\"}" >> "$OUT"
