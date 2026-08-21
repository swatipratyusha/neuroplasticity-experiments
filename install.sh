#!/bin/zsh
# Install the telemetry rig on this Mac: stage scripts into NEURO_HOME, render
# the launchd agents for your paths and hours, load them.
# Re-running is safe — it restages and reloads.
#
#   ./install.sh [--probe-hours 13-21] [--digest-at 21:47] [--no-neurolog]
set -eu
SRC="${0:A:h}"

PROBE_HOURS="13-21"
DIGEST_AT="21:47"
BUILD_NEUROLOG=1
while [ $# -gt 0 ]; do
  case "$1" in
    --probe-hours) PROBE_HOURS="$2"; shift 2 ;;
    --digest-at) DIGEST_AT="$2"; shift 2 ;;
    --no-neurolog) BUILD_NEUROLOG=0; shift ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

case "$PROBE_HOURS" in
  <0-23>-<0-23>) [ "${PROBE_HOURS%%-*}" -le "${PROBE_HOURS##*-}" ] || \
      { echo "--probe-hours start must not be after end: $PROBE_HOURS" >&2; exit 2; } ;;
  *) echo "--probe-hours must look like 13-21 (hours 0-23): $PROBE_HOURS" >&2; exit 2 ;;
esac
case "$DIGEST_AT" in
  <0-23>:<0-59>) ;;
  *) echo "--digest-at must look like 21:47: $DIGEST_AT" >&2; exit 2 ;;
esac

[ -f "$SRC/config.env" ] || cp "$SRC/config.example.env" "$SRC/config.env"
# An exported NEURO_HOME wins, exactly as it does for the instruments.
NEURO_HOME="${NEURO_HOME:-$(unset NEURO_HOME; . "$SRC/config.env"; echo "$NEURO_HOME")}"
NEURO_HOME="${NEURO_HOME:A}"          # resolve symlinks: a link out of Documents is still in Documents
case "$NEURO_HOME" in
  "$HOME"/Documents|"$HOME"/Desktop|"$HOME"/Downloads|"$HOME"/Documents/*|"$HOME"/Desktop/*|"$HOME"/Downloads/*)
    echo "NEURO_HOME is under a TCC-protected folder; launchd agents cannot read it." >&2
    echo "Pick a path outside Documents/Desktop/Downloads in config.env." >&2
    exit 1 ;;
esac

echo "Staging into $NEURO_HOME"
mkdir -p "$NEURO_HOME/bin" "$NEURO_HOME/data/telemetry" "$NEURO_HOME/data/digests"
cp "$SRC/bin/"*.sh "$SRC/bin/"*.py "$NEURO_HOME/bin/"
cp "$SRC/config.env" "$NEURO_HOME/config.env"
chmod +x "$NEURO_HOME/bin/"*

if [ "$BUILD_NEUROLOG" = "1" ]; then
  if command -v swiftc >/dev/null; then
    "$SRC/neurolog/build.sh" "$NEURO_HOME/neurolog"
    # A new status item is placed leftmost, which on a notched display puts it
    # under the notch where it cannot be clicked. Nudge it in from the right —
    # but only if unset, so a position dragged by hand later is not overwritten.
    POSITION=$(unset NEUROLOG_MENUBAR_POSITION; . "$SRC/config.env"; echo "${NEUROLOG_MENUBAR_POSITION:-300}")
    if ! defaults read com.neuroplasticity.neurolog "NSStatusItem Preferred Position Item-0" >/dev/null 2>&1; then
      defaults write com.neuroplasticity.neurolog "NSStatusItem Preferred Position Item-0" -int "$POSITION"
    fi
  else
    echo "swiftc not found (install Xcode command line tools) — skipping NeuroLog"
    BUILD_NEUROLOG=0
  fi
fi

START=${PROBE_HOURS%%-*}
END=${PROBE_HOURS##*-}
SLOTS=""
h=$START
while [ "$h" -le "$END" ]; do
  SLOTS="$SLOTS    <dict><key>Hour</key><integer>$h</integer><key>Minute</key><integer>3</integer></dict>"
  if [ "$h" -lt "$END" ]; then SLOTS="$SLOTS"$'\n'; fi
  h=$((h + 1))
done
DIGEST_HOUR=${DIGEST_AT%%:*}
DIGEST_MINUTE=${DIGEST_AT##*:}

# /usr/bin/python3 on a machine without developer tools is a stub that prompts
# for an install and fails under launchd — the digest agent would load and then
# never produce anything. Pin an interpreter that demonstrably runs.
PYTHON=$(command -v python3 || true)
if [ -z "$PYTHON" ] || ! "$PYTHON" -c "import csv" 2>/dev/null; then
  echo "No working python3 found — install Xcode command line tools" >&2
  echo "(xcode-select --install), then re-run. Sampler and probe will still" >&2
  echo "work; the nightly digest will not." >&2
  PYTHON=""
fi

AGENTS="$HOME/Library/LaunchAgents"
mkdir -p "$AGENTS"
# Templating happens in the shell, not through sed: a data root containing |, &
# or a backslash silently corrupts a sed replacement, and the result is an agent
# quietly pointed at the wrong directory. XML-escape what goes into the plist.
xml_escape() { local v=${1//&/&amp;}; v=${v//</&lt;}; print -r -- "${v//>/&gt;}"; }
NEURO_HOME_XML=$(xml_escape "$NEURO_HOME")
PYTHON_XML=$(xml_escape "$PYTHON")

render() {
  local label="$1" content
  content=$(<"$SRC/launchd/$label.plist.template")
  content=${content//__NEURO_HOME__/$NEURO_HOME_XML}
  content=${content//__PYTHON__/$PYTHON_XML}
  content=${content//__DIGEST_HOUR__/${DIGEST_HOUR#0}}
  content=${content//__DIGEST_MINUTE__/${DIGEST_MINUTE#0}}
  content=${content//__PROBE_SLOTS__/$SLOTS}
  print -r -- "$content" > "$AGENTS/$label.plist"
  plutil -lint "$AGENTS/$label.plist" >/dev/null
  launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || true
  launchctl bootstrap "gui/$(id -u)" "$AGENTS/$label.plist"
  echo "loaded $label"
}

# An agent we are deliberately not installing must not be left loaded from a
# previous run, still failing on its own schedule.
drop() {
  local label="$1"
  launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || true
  # Only remove the plist once the job is really gone. Deleting it while the
  # agent is still loaded hides a running job from both the installer and the
  # health check, which is the exact silent state this kit exists to avoid.
  if launchctl list 2>/dev/null | grep -q "$label"; then
    echo "warning: $label is still loaded and could not be unloaded; leaving its plist in place" >&2
    return
  fi
  if [ -f "$AGENTS/$label.plist" ]; then unlink "$AGENTS/$label.plist"; fi
  echo "not installed: $label"
}

render com.neuroplasticity.sample
render com.neuroplasticity.probe
if [ -n "$PYTHON" ]; then render com.neuroplasticity.digest; else drop com.neuroplasticity.digest; fi
if [ "$BUILD_NEUROLOG" = "1" ]; then render com.neuroplasticity.log; else drop com.neuroplasticity.log; fi

cat <<'NOTE'

Installed.

macOS will prompt once for Automation access ("... wants to control System
Events") on the first sample. Approve it — until you do, every telemetry row
records TCC_DENIED and the study collects nothing. Re-grant later under
System Settings > Privacy & Security > Automation.

Verify in a minute:  ./bin/healthcheck.sh
NOTE
