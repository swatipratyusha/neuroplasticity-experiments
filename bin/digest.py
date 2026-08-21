#!/usr/bin/env python3
"""Deterministic end-of-day digest: collate telemetry + probes + self-logged
events + transcript stats into data/digests/YYYY-MM-DD.md. No LLM involved —
interpretation is a separate, human (or agent) step."""
import csv
import os
import subprocess
import sys
from collections import Counter
from datetime import date
from pathlib import Path

BASE = Path(os.environ.get("NEURO_HOME",
                           Path.home() / "Library" / "Application Support" / "neuroplasticity"))
DAY = sys.argv[1] if len(sys.argv) > 1 else date.today().isoformat()


def load_telemetry():
    path = BASE / "data" / "telemetry" / f"{DAY}.csv"
    if not path.exists():
        return []
    with open(path) as f:
        return list(csv.DictReader(f))


def safe_int(v):
    try:
        return int(v)
    except (TypeError, ValueError):
        return 0


def summarize(rows):
    active = [r for r in rows if safe_int(r["idle_s"]) < 120]
    app_minutes = Counter(r["front_app"] for r in active)
    switches = sum(1 for a, b in zip(active, active[1:]) if a["front_app"] != b["front_app"])
    title_switches = sum(1 for a, b in zip(active, active[1:])
                         if a["front_title"] != b["front_title"])
    procs = [safe_int(r.get("agent_procs")) for r in active]
    tx = [safe_int(r.get("active_transcripts")) for r in active]
    return {
        "sampled_min": len(rows),
        "active_min": len(active),
        "app_minutes": app_minutes.most_common(8),
        "app_switches": switches,
        "title_switches": title_switches,
        "agent_procs_max": max(procs, default=0),
        "transcripts_max": max(tx, default=0),
    }


def load_day_rows(filename):
    path = BASE / "data" / filename
    if not path.exists():
        return []
    with open(path) as f:
        return [r for r in csv.DictReader(f) if r["ts"].startswith(DAY)]


def transcript_lines():
    """Miner output restricted to DAY (--days is a rolling window, so filter)."""
    miner = Path(__file__).resolve().parent / "mine_transcripts.py"
    if not miner.exists():
        return "(miner not found)"
    out = subprocess.run([sys.executable, str(miner), "--days", "2"],
                         capture_output=True, text=True, timeout=300).stdout
    lines = out.strip().splitlines()
    return "\n".join(lines[:1] + [ln for ln in lines[1:] if ln.startswith(DAY)])


def main():
    s = summarize(load_telemetry())
    probes = load_day_rows("probes.csv")
    events = load_day_rows("events.csv")
    lines = [f"# Digest — {DAY}", ""]
    lines += [f"- Active at machine: **{s['active_min']} min** of {s['sampled_min']} sampled",
              f"- App switches: **{s['app_switches']}** · window/tab switches: **{s['title_switches']}**",
              f"- Peak live agent processes: **{s['agent_procs_max']}** · peak concurrently-active transcripts: **{s['transcripts_max']}**",
              "", "## Time by app (active minutes)"]
    lines += [f"- {app or '(unknown)'}: {mins}" for app, mins in s["app_minutes"]]
    lines += ["", "## Agent session behavior (today)", "```", transcript_lines(), "```"]
    lines += ["", f"## Probes ({len(probes)} recorded)"]
    lines += [f"- {p['ts'][11:16]} — {p['raw']}" for p in probes]
    lines += ["", f"## Self-logged events ({len(events)})"]
    lines += [f"- {e['ts'][11:16]} — {e['raw']}" for e in events]
    out_dir = BASE / "data" / "digests"
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / f"{DAY}.md").write_text("\n".join(lines) + "\n")
    print(out_dir / f"{DAY}.md")


if __name__ == "__main__":
    main()
