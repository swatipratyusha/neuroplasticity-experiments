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
  else
    echo "swiftc not found (install Xcode command line tools) — skipping NeuroLog"
    BUILD_NEUROLOG=0
  fi
fi

START=${PROBE_HOURS%%-*}
END=${PROBE_HOURS##*-}
SLOT_FILE=$(mktemp)
h=$START
while [ "$h" -le "$END" ]; do
  echo "    <dict><key>Hour</key><integer>$h</integer><key>Minute</key><integer>3</integer></dict>" >> "$SLOT_FILE"
  h=$((h + 1))
done
trap 'rm -f "$SLOT_FILE"' EXIT
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
NEURO_HOME_SED=${NEURO_HOME//[|&\\]/\\&}   # | delimits, & back-references
render() {
  local label="$1"
  sed -e "s|__NEURO_HOME__|$NEURO_HOME_SED|g" \
      -e "s|__PYTHON__|$PYTHON|g" \
      -e "s|__DIGEST_HOUR__|${DIGEST_HOUR#0}|g" \
      -e "s|__DIGEST_MINUTE__|${DIGEST_MINUTE#0}|g" \
      -e "/__PROBE_SLOTS__/r $SLOT_FILE" \
      -e "/__PROBE_SLOTS__/d" \
      "$SRC/launchd/$label.plist.template" > "$AGENTS/$label.plist"
  plutil -lint "$AGENTS/$label.plist" >/dev/null
  launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || true
  launchctl bootstrap "gui/$(id -u)" "$AGENTS/$label.plist"
  echo "loaded $label"
}
render com.neuroplasticity.sample
render com.neuroplasticity.probe
if [ -n "$PYTHON" ]; then render com.neuroplasticity.digest; fi
if [ "$BUILD_NEUROLOG" = "1" ]; then render com.neuroplasticity.log; fi

cat <<'NOTE'

Installed.

macOS will prompt once for Automation access ("... wants to control System
Events") on the first sample. Approve it — until you do, every telemetry row
records TCC_DENIED and the study collects nothing. Re-grant later under
System Settings > Privacy & Security > Automation.

Verify in a minute:  ./bin/healthcheck.sh
NOTE
