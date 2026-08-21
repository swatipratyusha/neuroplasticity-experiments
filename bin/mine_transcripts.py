#!/usr/bin/env python3
"""Mine agent transcripts (~/.claude/projects/*/*.jsonl) for behavioral focus
metrics. Nothing is sent anywhere; only timestamps and roles are read, never
prompt text.

Per day, reconstructs from user-turn timestamps:
  - sessions_touched: distinct sessions with >=1 user turn
  - user_turns: total prompts sent
  - interleave_switches: consecutive user turns that jumped to a different session
  - max_parallel_hour: most distinct sessions prompted within any single hour
  - attention latency: gap between an assistant turn finishing and the user's next
    turn in that session (median + p90, seconds, capped at 30 min to exclude
    walked-away gaps)

Usage: mine_transcripts.py [--days N] [--csv OUT] [--projects DIR]
"""
import argparse
import json
import os
import statistics
from collections import defaultdict
from datetime import datetime, timedelta
from pathlib import Path

DEFAULT_PROJECTS = Path.home() / ".claude" / "projects"
LATENCY_CAP_S = 1800
LOCAL_TZ = datetime.now().astimezone().tzinfo


def parse_ts(raw):
    try:
        return datetime.fromisoformat(raw.replace("Z", "+00:00")).astimezone(LOCAL_TZ)
    except (ValueError, AttributeError):
        return None


def iter_turns(path):
    """Yield (ts, role, session_id) for real turns in one transcript.

    A "user" turn counts only when it is a genuine typed prompt: string content,
    not a tool_result echo (list content), not isMeta (system-injected), not a
    subagent sidechain. Assistant turns likewise exclude sidechains.
    """
    session = path.stem
    with open(path, errors="replace") as f:
        for line in f:
            try:
                rec = json.loads(line)
            except json.JSONDecodeError:
                continue
            role = rec.get("type")
            if role not in ("user", "assistant") or rec.get("isSidechain"):
                continue
            if role == "user":
                if rec.get("isMeta"):
                    continue
                msg = rec.get("message")
                if not isinstance(msg, dict) or not isinstance(msg.get("content"), str):
                    continue
            ts = parse_ts(rec.get("timestamp"))
            if ts:
                yield ts, role, session


def collect(days, projects):
    cutoff = datetime.now(LOCAL_TZ) - timedelta(days=days)
    turns = []
    for path in Path(projects).glob("*/*.jsonl"):
        try:
            if datetime.fromtimestamp(path.stat().st_mtime, LOCAL_TZ) < cutoff:
                continue
        except OSError:
            continue
        turns.extend(t for t in iter_turns(path) if t[0] >= cutoff)
    turns.sort(key=lambda t: t[0])
    return turns


def daily_stats(turns):
    days = defaultdict(lambda: {"user_turns": 0, "sessions": set(), "switches": 0,
                                "hourly": defaultdict(set), "latencies": []})
    last_user_session = {}          # day -> session of previous user turn
    last_assistant_ts = {}          # session -> ts of most recent assistant turn
    for ts, role, session in turns:
        day = ts.strftime("%F")
        if role == "assistant":
            last_assistant_ts[session] = ts
            continue
        d = days[day]
        d["user_turns"] += 1
        d["sessions"].add(session)
        d["hourly"][ts.hour].add(session)
        prev = last_user_session.get(day)
        if prev is not None and prev != session:
            d["switches"] += 1
        last_user_session[day] = session
        a_ts = last_assistant_ts.get(session)
        if a_ts is not None:
            gap = (ts - a_ts).total_seconds()
            if 0 < gap <= LATENCY_CAP_S:
                d["latencies"].append(gap)
    return days


def render(days, csv_out=None):
    header = ("day", "sessions", "user_turns", "interleave_switches",
              "max_parallel_hour", "latency_med_s", "latency_p90_s")
    rows = []
    for day in sorted(days):
        d = days[day]
        lat = sorted(d["latencies"])
        med = round(statistics.median(lat)) if lat else ""
        # nearest-rank p90: smallest value with >=90% of samples at or below it
        p90 = round(lat[min(len(lat) - 1, -(-len(lat) * 9 // 10) - 1)]) if len(lat) >= 5 else ""
        max_par = max((len(s) for s in d["hourly"].values()), default=0)
        rows.append((day, len(d["sessions"]), d["user_turns"], d["switches"], max_par, med, p90))
    widths = [max(len(str(x)) for x in [h] + [r[i] for r in rows]) for i, h in enumerate(header)]
    print("  ".join(h.ljust(w) for h, w in zip(header, widths)))
    for r in rows:
        print("  ".join(str(x).ljust(w) for x, w in zip(r, widths)))
    if csv_out:
        with open(csv_out, "w") as f:
            f.write(",".join(header) + "\n")
            for r in rows:
                f.write(",".join(str(x) for x in r) + "\n")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--days", type=int, default=14)
    ap.add_argument("--csv")
    ap.add_argument("--projects", default=os.environ.get("NEURO_TRANSCRIPT_DIR", DEFAULT_PROJECTS))
    args = ap.parse_args()
    render(daily_stats(collect(args.days, args.projects)), args.csv)
