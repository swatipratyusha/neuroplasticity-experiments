#!/bin/zsh
# Unload the launchd agents and delete the rendered plists.
# Collected data is deliberately left alone; delete NEURO_HOME yourself if you
# want it gone.
set -u
for label in sample probe digest log; do
  launchctl bootout "gui/$(id -u)/com.neuroplasticity.$label" 2>/dev/null || true
  PLIST="$HOME/Library/LaunchAgents/com.neuroplasticity.$label.plist"
  [ -f "$PLIST" ] && unlink "$PLIST"
  echo "removed com.neuroplasticity.$label"
done
echo "Data left in place under NEURO_HOME."
