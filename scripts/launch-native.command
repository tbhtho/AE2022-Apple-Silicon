#!/bin/bash
# Launch After Effects 2022 natively (arm64). Fast to start, but only universal
# plugins load: Intel-only plugins stay inactive. Pass a project path to open it.
#
#   ./launch-native.command
#   ./launch-native.command "/path/to/project.aep"

set -u
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

require_ae

pid="$(ae_pid)"
if [ -n "$pid" ]; then
    echo "After Effects is already running (pid $pid), code type: $(ae_mode "$pid")"
    echo "Quit it first, or use restart-clean.command --native to switch modes."
    exit 0
fi

echo "Launching After Effects natively (arm64)..."
ae_launch arm64 "$@" || exit 1
