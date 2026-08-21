# Data dictionary

All files live under `$NEURO_HOME/data`. Everything is local; nothing is
uploaded anywhere by this repo.

## `telemetry/YYYY-MM-DD.csv` — one row per minute

| column | meaning |
|---|---|
| `ts` | local time, `YYYY-MM-DDTHH:MM:SS` |
| `idle_s` | seconds since last input. Rows with `idle_s >= 120` are treated as "away" by the digest. An **empty** value means `ioreg` failed; such rows are excluded from active minutes rather than counted as zero-idle |
| `front_app` | frontmost application name. `TCC_DENIED` means the sampler could not read it at all — almost always a refused Automation grant, occasionally another scripting error. Either way the minute is **missing data, not an empty desktop**, and the digest counts it separately |
| `front_title` | frontmost window/tab title (iTerm2 is queried directly — System Events cannot see its window names) |
| `agent_procs` | running processes matching `SAMPLE_AGENT_PROC_MATCH` |
| `active_transcripts` | transcript files modified in the last 2 minutes — a live-session count that survives detached processes |
| `docker_containers` | running containers, or empty when `SAMPLE_TRACK_DOCKER=0` |

## `probes.csv` — randomly-timed subjective samples

| column | meaning |
|---|---|
| `ts` | when the dialog was answered |
| `raw` | your answer, stored verbatim |

`raw` is deliberately unparsed. Free-form answers do not survive rigid field
splitting at write time; parse them at analysis time when you can see the whole
distribution. Two sentinel values matter: `(empty)` means the dialog timed out
unanswered, `(probe-failed rc=…)` means it could not be shown — usually a TCC
denial. Neither counts toward the daily cap.

## `events.csv` — self-initiated log (NeuroLog)

Same two columns. Kept separate from `probes.csv` on purpose: probes are a
random sample of your states, events are a biased sample of what you noticed.
Mixing them silently biases every rate you compute.

## `digests/YYYY-MM-DD.md`

Deterministic nightly collation of the above plus the transcript metrics. No
model is involved — interpretation is a separate step, so the record stays
reproducible.

## `probe_runs.log`

One line per probe invocation: `firing`, `skip-gate`, `skip-idle`, `skip-cap`,
`skip-locked`. This is how you tell "I answered nothing today" apart from "the
probe never fired", which otherwise look identical in `probes.csv`.
