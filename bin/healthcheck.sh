#!/bin/zsh
# Is the rig actually collecting? One line per instrument; exits 1 if anything
# is dead. Silence is the failure mode this study is most exposed to.
#
# Unlike the instruments, this resolves the data root from config.env: it is run
# by hand from a clone, where the script's own location is NOT where data lives.
set -u
SELF="${0:A:h}"
if [ -z "${NEURO_HOME:-}" ]; then
  for candidate in "$SELF/../config.env" "$SELF/config.env"; do
    [ -f "$candidate" ] && { . "$candidate"; break }
  done
  : "${NEURO_HOME:=$HOME/Library/Application Support/neuroplasticity}"
fi
DATA="$NEURO_HOME/data"
FAIL=0
say() { echo "$1"; }
bad() { echo "$1"; FAIL=1; }
say "      data root: $NEURO_HOME"

# The log agent is optional — installing with --no-neurolog is a valid choice,
# so only demand it when the app is actually present.
JOBS=(sample probe digest)
[ -d "$NEURO_HOME/neurolog/NeuroLog.app" ] && JOBS+=(log)
for job in $JOBS; do
  if launchctl list 2>/dev/null | grep -q "com.neuroplasticity.$job"; then
    say "ok    agent com.neuroplasticity.$job loaded"
  else
    bad "DEAD  agent com.neuroplasticity.$job not loaded"
  fi
done

TODAY="$DATA/telemetry/$(date +%F).csv"
if [ -f "$TODAY" ]; then
  ROWS=$(( $(wc -l < "$TODAY") - 1 ))
  AGE=$(( $(date +%s) - $(stat -f %m "$TODAY") ))
  [ "$AGE" -lt 300 ] && say "ok    telemetry $ROWS rows, last write ${AGE}s ago" \
                     || bad "STALE telemetry $ROWS rows, last write ${AGE}s ago"
  DENIED=$(grep -c "TCC_DENIED" "$TODAY" || true)
  [ "$DENIED" -gt 0 ] && bad "TCC   $DENIED rows could not read the frontmost app — grant Automation access in System Settings > Privacy & Security > Automation. Those minutes are blind, not idle."
  # An unreadable idle time is not a zero: the digest must not count those
  # minutes as time spent at the machine.
  BLANK_IDLE=$(awk -F, 'NR>1 && $2 !~ /^[0-9]+$/' "$TODAY" | grep -c . || true)
  [ "$BLANK_IDLE" -gt 0 ] && bad "ERR   $BLANK_IDLE rows have no idle time — ioreg failed for those samples"
else
  bad "DEAD  no telemetry file for today"
fi

if [ -f "$DATA/probes.csv" ]; then
  for d in 0 1 2; do
    DAY=$(date -v-${d}d +%F)
    N=$(grep -c "^$DAY" "$DATA/probes.csv" || true)
    say "      probes $DAY: $N"
  done
  grep -q "probe-failed" "$DATA/probes.csv" && bad "ERR   probes.csv contains probe-failed rows — read them, usually a denied Automation grant"
else
  say "      probes.csv not created yet (normal before the first probe window)"
fi

say "      latest digest: $(ls -1 "$DATA/digests" 2>/dev/null | tail -1 || echo none)"

for log in sample.err.log probe.err.log digest.err.log; do
  [ -s "$DATA/$log" ] && bad "ERR   $log is non-empty: $(tail -1 "$DATA/$log")"
done

exit $FAIL
