#!/bin/zsh
# Is the rig actually collecting? Prints one line per instrument, exits 1 if
# anything is dead. Silence is the failure mode this study is most exposed to.
set -u
. "${0:A:h}/common.sh"
FAIL=0
say() { echo "$1"; }
bad() { echo "$1"; FAIL=1; }

for job in sample probe digest log; do
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
  grep -q "TCC_DENIED" "$TODAY" && bad "TCC   sampler was denied Automation access (grant it in System Settings > Privacy > Automation)"
else
  bad "DEAD  no telemetry file for today"
fi

if [ -f "$DATA/probes.csv" ]; then
  for d in 0 1 2; do
    DAY=$(date -v-${d}d +%F)
    N=$(grep -c "^$DAY" "$DATA/probes.csv" || true)
    say "      probes $DAY: $N"
  done
  grep -q "probe-failed" "$DATA/probes.csv" && bad "ERR   probes.csv contains probe-failed rows — inspect them"
else
  say "      probes.csv not created yet (normal before the first probe window)"
fi

LAST_DIGEST=$(ls -1 "$DATA/digests" 2>/dev/null | tail -1)
say "      latest digest: ${LAST_DIGEST:-none}"

for log in sample.err.log probe.err.log digest.err.log; do
  [ -s "$DATA/$log" ] && bad "ERR   $log is non-empty: $(tail -1 "$DATA/$log")"
done

exit $FAIL
