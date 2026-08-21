---
name: neuro-health
description: Diagnose a neuroplasticity telemetry rig that has gone quiet or is collecting suspect data — dead launchd agents, TCC denial, probes not firing, stale digests, gaps in telemetry. Use when asked "is the rig still running", "why did I get no probes", "check my telemetry", or during a weekly spot-check.
---

# Diagnosing the rig

The threat model: **silent instrument death**. Every failure here produces
missing data, and missing data looks exactly like a quiet day. Never conclude
"low activity" from an absence until you have ruled out the instrument.

Start with `bin/healthcheck.sh`. It exits non-zero on any dead agent, stale
telemetry, TCC denial, or non-empty error log. Then work the symptom.

## Telemetry missing or stale

1. `launchctl list | grep neuroplasticity` — is `com.neuroplasticity.sample`
   loaded? If not: `./install.sh` re-renders and reloads.
2. Check `data/sample.err.log`. Non-empty is a real error, not noise.
3. Run the sampler by hand with the right `NEURO_HOME` and read the row it
   writes.
4. **Gaps mid-day are usually sleep, not failure.** Cross-check the gap against
   `pmset -g log | grep -E 'Sleep|Wake'` before calling it a fault. A closed lid
   produces a clean gap; a dead agent produces a gap that never ends.

## Rows say `TCC_DENIED`

macOS revoked or never granted Automation access. Every such row is a blind
minute — not an idle one. Fix in System Settings → Privacy & Security →
Automation, then verify with a hand-run sample. Count how many rows were
affected and tell the user the exact window that is unusable; do not leave those
rows to be silently averaged into results later.

## No probes today

`data/probe_runs.log` is the ground truth, and the distinction matters:

| Line | Meaning |
|---|---|
| `skip-gate` | The probability gate declined. Normal — expect roughly `100 - PROBE_FIRE_PCT`% of slots |
| `skip-idle` | They were away from the machine. Normal |
| `skip-cap` | Daily cap already met. Normal |
| `skip-locked` | A dialog was already open. Rare; investigate if frequent |
| `firing` / `firing-stratified` | It fired — so if `probes.csv` has no matching row, the *dialog* failed, not the schedule |
| (no lines at all) | The agent never ran. Real failure |

If the log shows `firing` but `probes.csv` shows `(probe-failed rc=…)`, read the
rc: this is almost always TCC. If answers are consistently `(empty)`, the dialog
appears but goes unanswered — either it is opening behind a full-screen window,
or the timeout is too short for how they work. Suggest raising
`PROBE_TIMEOUT_S`; do not quietly discard the empties, they are data about
availability.

## Probe rate is well below the cap

Expected daily firings ≈ `(number of hourly slots) × PROBE_FIRE_PCT / 100`,
capped at `PROBE_DAILY_CAP`, minus idle skips. Compute it against their actual
config before calling the rate wrong. If they genuinely want more samples, raise
`PROBE_FIRE_PCT` or widen the window — and note in the protocol *when* the
change happened, because the sampling rate changed mid-study and any before/
after comparison must account for it.

## Digest missing

The nightly agent only fires if the machine is awake at that minute; `launchd`
does not catch up a missed `StartCalendarInterval` while asleep. Backfill any
day on demand:

```sh
NEURO_HOME=<root> python3 bin/digest.py 2026-01-06
```

## Reporting

Report what is broken, for how long, and **which date ranges are unusable as a
result**. That last part is what protects the analysis; a fixed agent does not
retroactively fill the hole it left.
