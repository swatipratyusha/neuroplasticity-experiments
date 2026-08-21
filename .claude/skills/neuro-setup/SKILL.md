---
name: neuro-setup
description: Install and verify the neuroplasticity telemetry rig on this Mac — stage the instruments, render and load the launchd agents, walk the macOS Automation grant, and confirm real data is landing. Use when asked to "set up the telemetry", "install the neuro rig", "start collecting", or after cloning this repo.
---

# Setting up the rig

Goal: the user leaves this with four agents loaded **and first-hand evidence
that data is actually being written**. A rig that installs cleanly and then
collects nothing is the failure mode worth designing against — it looks like
success for days.

## 1. Settle the config before installing

Read `config.example.env`. Ask the user only what you cannot infer:

- **Probe window** — the hours they are usually at the machine. Default 13-21.
  A probe that fires while they are asleep burns a daily-cap slot on `(empty)`.
- **Data root** — default `~/Library/Application Support/neuroplasticity` is
  right for almost everyone. If they want it elsewhere, it must be outside
  `~/Documents`, `~/Desktop`, `~/Downloads` (launchd cannot read those under
  macOS TCC). `install.sh` enforces this; do not work around it.
- **Agent process match** — `claude` by default. Change if they drive a
  different agent CLI.

Copy to `config.env` and edit before running the installer, not after.

## 2. Install

```sh
./install.sh --probe-hours <start>-<end> --digest-at HH:MM
```

If `swiftc` is missing, the NeuroLog menu-bar app is skipped and the other three
instruments still work. Say so plainly rather than treating it as a failure;
offer `xcode-select --install` if they want the app.

## 3. Force the Automation grant now, not at 2am

The sampler needs Automation access to System Events. Trigger the prompt
deliberately:

```sh
NEURO_HOME=<data root> zsh bin/sample.sh
tail -1 "<data root>/data/telemetry/$(date +%F).csv"
```

If that row shows `TCC_DENIED`, the grant was refused or never shown. Send them
to System Settings → Privacy & Security → Automation and re-run. **Do not
declare setup complete while a TCC_DENIED row is the most recent one** — the
whole study is blind in that state and nothing downstream will say so.

## 4. Smoke-test the probe

```sh
FORCE=1 NEURO_HOME=<data root> zsh bin/probe.sh
```

`FORCE=1` bypasses the probability gate and the random delay. A dialog must
appear. Confirm the answer lands in `data/probes.csv`, then tell the user this
test row exists so they can drop it before analysis.

## 5. Take the free retrospective baseline

```sh
./bin/mine_transcripts.py --days 14 --csv baseline.csv
```

Show them the table. This is history they already had — sessions, prompts,
interleave switches, attention latency — and it is the comparison point for
everything collected from here.

## 6. Hand off

Run `bin/healthcheck.sh` and report its output. Then point them at
`docs/PROTOCOL-template.md` and say the part that matters: **write the protocol
before the data accumulates.** A question chosen after looking at the data is
not a question, it is a description.
