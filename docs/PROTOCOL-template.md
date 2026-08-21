# Measurement Protocol — <your study name>

Copy this file to `PROTOCOL.md` (gitignored by default if you keep it out of the
repo) and fill it in **before** you start collecting. A protocol written after
the data is in is a story, not a study.

**Subject:** <who>
**Phase 1 (baseline):** <start date> → <end date>. Observation only — no
behaviour change attempted. Changing habits while measuring them destroys the
baseline you would compare against later.
**Question:** <the one question this phase answers. One sentence. If you cannot
write it in one sentence you are not ready to collect.>

## Instruments

| Instrument | Mechanism | Cadence | Output |
|---|---|---|---|
| Passive sampler | `bin/sample.sh` via `com.neuroplasticity.sample` | every 60s, always | `data/telemetry/YYYY-MM-DD.csv` |
| Subjective probe | `bin/probe.sh` via `com.neuroplasticity.probe` | hourly slots `<start>–<end>`, fires ~`PROBE_FIRE_PCT`% with a random in-hour delay, cap `PROBE_DAILY_CAP`/day, skipped when idle | `data/probes.csv` |
| Transcript miner | `bin/mine_transcripts.py` | on demand / inside the digest | per-day session and latency metrics |
| Self-logged events | NeuroLog menu-bar app | whenever you notice something | `data/events.csv` |
| Nightly digest | `bin/digest.py` via `com.neuroplasticity.digest` | daily at `<time>` | `data/digests/YYYY-MM-DD.md` |

Probe answer format: `<your one-line format — keep it identical every day>`

## Metrics and what each one is a proxy for

- **Attention latency** — gap between an assistant turn finishing and your next
  prompt in that session, capped at 30 min. Proxy for *was this thread being
  watched*, not for how fast you type.
- **Interleave switches** — consecutive prompts landing in different sessions.
  Proxy for context-switch rate.
- **max_parallel_hour** — distinct sessions prompted within one hour. Proxy for
  the load you were actually carrying, not the number of windows open.
- **App / window-title churn** — from telemetry, correlate against probe scores.

State your expected direction for each metric before you look. Writing the
prediction down is what separates a finding from a rationalisation.

## Baseline (fill after the first mine)

`bin/mine_transcripts.py --days 14 --csv baseline.csv` gives a retrospective
baseline from transcripts that already exist — you get history for free on day
one. Record the ranges here.

## Analysis plan (commit to this before day 1)

1. Time-of-day curves: latency, switch churn, probe scores.
2. Load dose-response: sessions-active-per-hour vs latency and error-correction
   turns ("wait", "go back", "no I meant").
3. Probe-anchored event studies: what does telemetry show in the 15 minutes
   before a low focus report?
4. Capability envelope: how much parallelism before p90 latency blows up.

Minimum days before analysing: `<N>` — say it now so a tempting early pattern
does not become the conclusion.

## Ops notes

- Data root must live outside `~/Documents`, `~/Desktop`, `~/Downloads`: launchd
  agents cannot read those (macOS TCC).
- Weekly: run `bin/healthcheck.sh` and confirm probes are landing at the
  expected rate. Silent instrument death is the main threat to a study this
  cheap.
