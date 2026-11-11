#!/bin/bash
# Launch After Effects 2022 under Rosetta so Intel-only (x86_64) plugins load.
# Slower to start than native. Pass a project path to open it.
#
#   ./launch-rosetta.command
#   ./launch-rosetta.command "/path/to/project.aep"

set -u
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

require_ae
require_rosetta

pid="$(ae_pid)"
if [ -n "$pid" ]; then
    echo "After Effects is already running (pid $pid), code type: $(ae_mode "$pid")"
    echo "Quit it first, or use restart-clean.command to switch modes."
    exit 0
fi

echo "Launching After Effects under Rosetta (x86_64)..."
ae_launch x86_64 "$@" || exit 1
echo "The plugin scan can take a minute or more with large suites installed."
