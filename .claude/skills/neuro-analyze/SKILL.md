---
name: neuro-analyze
description: Analyze collected neuroplasticity telemetry — time-of-day focus curves, parallel-load dose-response, probe-anchored event studies, and the capability envelope — and write an honest report of what the data does and does not support. Use when asked to "analyze my focus data", "what does the telemetry say", "run the fortnight analysis", or "what breaks my focus".
---

# Analysing the data

You are analysing someone's own behaviour and reporting it back to them. Two
failure modes to avoid, in order of how much damage they do:

1. **Finding a pattern the sample cannot support.** With ~5 probes a day, two
   weeks is ~70 subjective points. That supports coarse contrasts (morning vs
   evening, 1-3 threads vs 8+). It does not support "focus peaks at 15:00".
2. **Hedging everything into uselessness.** A real contrast in a small sample is
   still worth acting on if you say how strong it is. State effect sizes and
   sample counts, then let them decide.

## Inputs

Read from `$NEURO_HOME/data` (default `~/Library/Application Support/neuroplasticity`):
`telemetry/*.csv`, `probes.csv`, `events.csv`, `digests/*.md`, `probe_runs.log`.
`docs/data-dictionary.md` defines every column and sentinel. If there is no real
data yet, `samples/*.csv` in the repo exercise the same path.

Write intermediate frames to files as you go rather than holding them in
context; the analysis is worth re-running.

## Before computing anything

Establish the denominator and state it in the report:

- Days covered, and days with **usable** telemetry (exclude `TCC_DENIED` runs
  and long gaps — check `pmset -g log` to tell sleep from failure).
- Probes: real answers vs `(empty)` vs `(probe-failed)`. Only real answers are
  the sample.
- Whether config changed mid-window (probe window, fire percentage). A changed
  sampling rate breaks naive pooling across the boundary.
- Test rows from setup (`FORCE=1` probes) — drop them, and say you did.

Parse `probes.csv` `raw` here, at analysis time. It is stored unparsed on
purpose: read the actual answers and work out the format the user really used,
which will not perfectly match the format they intended. Handle the deviations
rather than dropping the rows that deviate.

## The four analyses

**1. Time-of-day curves.** Attention latency, app/title switch churn, and probe
focus scores by hour. Pool hours into blocks until each block has enough
samples to mean something; say what the block size is.

**2. Load dose-response.** The central question: does carrying more parallel
sessions degrade attention, and where does it turn? Bin by
`max_parallel_hour` (or concurrent `active_transcripts`) and look at median and
p90 latency, plus error-correction turns per prompt — count prompts matching
corrections like "wait", "no I meant", "go back", "undo" from transcripts.
Report the shape (flat, linear, or a knee) and where the knee sits. Beware the
obvious confound: heavy-load hours are also the user's peak hours. Say so.

**3. Probe-anchored event studies.** For each probe reporting low focus (≤2),
pull the 15 minutes of telemetry preceding it, and the same for high-focus
(≥4) probes. Compare switch churn, app mix, agent process count, idle pattern.
This is the analysis that answers *what precedes focus loss* rather than *what
correlates with it*. With few low-focus probes, present them as cases with their
telemetry rather than as a statistic — n=6 case descriptions are honest, an n=6
mean is not.

**4. Capability envelope.** The most parallel sessions sustained without p90
latency blowing up, and what the ceiling looks like when crossed. This is the
number the user actually wants: how much can they carry.

Cross-check the objective and subjective streams against each other. Where
telemetry says one thing and probes say another, that disagreement is a finding
— self-report and behaviour diverging is precisely what this rig exists to
detect. Do not quietly favour whichever supports a cleaner story.

## Reporting

Write a dated report to the user's own directory (never into the repo — the
`.gitignore` keeps data out and analysis of that data is data). Include:

- Denominators up front: days, usable days, probe counts by type.
- Findings with effect sizes and n, strongest first.
- **What this data cannot answer**, stated explicitly. Baseline observation
  cannot establish causation; only a Phase 2 intervention with before/after can.
- Concrete next steps: which interventions the findings actually justify testing,
  and what would need to be measured to know whether one worked.

Then offer, do not assume: charts if they want them, or a shorter version to
send someone.
