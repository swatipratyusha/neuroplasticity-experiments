# neuroplasticity-experiments

Self-experiments on focus, attention and context-switching while running many
parallel AI-agent sessions — instrumented on your own machine, with your data
staying on your own machine.

> **Where this is right now.** What is in the repo today is deliberately
> rudimentary: a passive telemetry sampler, a randomly-timed subjective probe,
> a miner over agent transcripts, and a nightly digest. It measures; it does not
> yet intervene, model, or conclude anything for you. Over the next month or two
> this will grow into the rest of the programme — analysis over collected
> baselines, then Phase 2 interventions (training protocols) with before/after
> comparison. The measurement layer is first because everything after it is
> worthless without a clean baseline.

macOS only, for now — the instruments lean on `launchd`, `osascript` and
`ioreg`.

## What it measures

| Stream | What it is | Why it is separate |
|---|---|---|
| **Telemetry** (60s) | frontmost app + window title, idle time, live agent processes, active transcripts, running containers | Objective, continuous, costs you nothing to produce |
| **Probes** (~5/day, random) | a one-line dialog: focus 1-5, threads in your head, what you are doing, what broke focus | A *random* sample of your states — the only kind you can compute honest rates from |
| **Events** (menu bar, on demand) | one-tap "interrupted", "focus dipping", "overloaded", or a free note | A *biased* sample of what you noticed. Kept apart from probes on purpose |
| **Transcript metrics** | sessions touched, prompts, interleave switches, max parallel sessions per hour, attention latency (median + p90) | Behaviour, reconstructed from timestamps you already generated |

Nothing but timestamps and roles are read from transcripts — never prompt text.
Nothing leaves the machine. `.gitignore` refuses to commit any collected data.

**Attention latency** is the metric worth explaining: the gap between an agent
finishing its turn and you sending the next prompt in that session, capped at
30 minutes. It is a proxy for *was this thread being watched* — a thread you
have mentally dropped shows up as a long gap long before you would report having
dropped it.

## Install

```sh
git clone https://github.com/swatipratyusha/neuroplasticity-experiments.git
cd neuroplasticity-experiments
cp config.example.env config.env     # edit the probe window, cap, question
./install.sh --probe-hours 13-21 --digest-at 21:47
./bin/healthcheck.sh
```

`install.sh` stages the scripts into `NEURO_HOME` (default
`~/Library/Application Support/neuroplasticity`), builds the NeuroLog menu-bar
app if `swiftc` is available, renders four `launchd` agents for your paths and
hours, and loads them. Re-running it is safe.

macOS will prompt once for Automation access. **Approve it** — until you do,
every telemetry row records `TCC_DENIED` and you are collecting nothing. The
health check calls this out rather than letting it look like quiet evenings.

The data root must live outside `~/Documents`, `~/Desktop` and `~/Downloads`:
launchd agents cannot read those directories (macOS TCC). `install.sh` refuses
such a path rather than installing something that silently never writes.

Remove everything with `./uninstall.sh` (agents go, your data stays).

## Free baseline on day one

If you have been using an agent CLI for a while, you already have history:

```sh
./bin/mine_transcripts.py --days 14 --csv baseline.csv
```

That reconstructs two weeks of sessions, prompts, interleave switches and
attention latency from existing transcripts — a retrospective baseline before
the first live sample lands.

## Claude Code skills

If you use Claude Code, `.claude/skills/` ships three skills that make the rig
operable in plain language:

| Skill | Does |
|---|---|
| `neuro-setup` | Installs and verifies the rig, walks the TCC grant, confirms first data lands |
| `neuro-health` | Diagnoses a rig that has gone quiet — dead agents, TCC denial, probe gate misfires, stale digests |
| `neuro-analyze` | Runs the analysis over your collected data: time-of-day curves, load dose-response, probe-anchored event studies, and an honest statement of what the sample cannot support |

They work from a clone; there is no server, account, or key involved.

## Designing your own study

`docs/PROTOCOL-template.md` is the part that matters more than the code. Fill it
in before you collect: the one question, the expected direction of each metric,
the minimum days before you are allowed to analyse. `docs/data-dictionary.md`
documents every column and the sentinel values that distinguish "nothing
happened" from "the instrument was blind".

## Layout

```
bin/            sample.sh · probe.sh · mine_transcripts.py · digest.py · healthcheck.sh
launchd/        plist templates rendered by install.sh
neurolog/       NeuroLog.app source (Swift) + build script
docs/           protocol template · data dictionary
samples/        synthetic CSVs so the analysis path runs before you have data
.claude/skills/ setup · health · analyze
```

MIT licensed.
