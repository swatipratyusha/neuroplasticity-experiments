# Shared bootstrap for the shell instruments: resolve the data root, load config.
#
# The data root comes from NEURO_HOME if the caller set one, otherwise from where
# this file physically sits (bin/../). It is resolved *before* config.env is
# sourced, and config.env assigns only with :=, so an explicit environment value
# always wins. Without that, a test pointed at a scratch root would be silently
# redirected into real collected data.
_neuro_self="${${(%):-%x}:A}"
: "${NEURO_HOME:=${_neuro_self:h:h}}"
[ -f "$NEURO_HOME/config.env" ] && . "$NEURO_HOME/config.env"
: "${SAMPLE_TRACK_DOCKER:=1}"
: "${SAMPLE_AGENT_PROC_MATCH:=claude}"
: "${SAMPLE_TRANSCRIPT_DIR:=$HOME/.claude/projects}"
: "${PROBE_DAILY_CAP:=5}"
: "${PROBE_FIRE_PCT:=55}"
: "${PROBE_MAX_DELAY_S:=2400}"
: "${PROBE_IDLE_SKIP_S:=600}"
: "${PROBE_EVENING_HOUR:=20}"
: "${PROBE_TIMEOUT_S:=300}"
: "${PROBE_QUESTION:=focus 1-5 | threads in head | doing what | what broke focus (- if nothing)}"
DATA="$NEURO_HOME/data"
idle_seconds() { ioreg -c IOHIDSystem | awk '/HIDIdleTime/ {printf "%d", $NF/1000000000; exit}'; }
