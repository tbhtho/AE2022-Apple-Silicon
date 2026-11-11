#!/bin/bash
# Restart After Effects 2022 with a clean plugin rescan.
#
# Why: AE only scans plugins at launch and caches a verdict per plugin. After
# installing, removing or moving plugins you have to restart with that cache
# cleared, otherwise the Effects menu keeps showing the old set.
#
#   ./restart-clean.command                        Rosetta, clear plugin cache
#   ./restart-clean.command --native               arm64 instead of Rosetta
#   ./restart-clean.command --disk-cache           also empty AE's disk cache
#   ./restart-clean.command "/path/to/project.aep" reopen a project afterwards
#
# Save your project before running this. It asks AE to quit normally. If a
# dialog blocks the quit, it stops and tells you instead of force-killing.

set -u
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

want="x86_64"
disk=0
while [ $# -gt 0 ]; do
    case "$1" in
        --native)     want="arm64"; shift ;;
        --disk-cache) disk=1; shift ;;
        --)           shift; break ;;
        -*)           echo "unknown option: $1" >&2; exit 2 ;;
        *)            break ;;
    esac
done

require_ae
[ "$want" = "x86_64" ] && require_rosetta

echo "After Effects $AE_VERSION: clean restart ($want)"
echo

ae_quit || exit 1

# The native host reads PluginCache.ARM64.*, the translated host reads
# PluginCache. Clearing only one of them leaves stale verdicts behind.
if [ -f "$AE_PLIST" ]; then
    keys=$(plutil -convert xml1 -o - "$AE_PLIST" 2>/dev/null \
           | grep -o '<key>PluginCache[^<]*</key>' \
           | sed 's/<[^>]*>//g')
    if [ -n "$keys" ]; then
        echo "$keys" | while IFS= read -r k; do
            [ -n "$k" ] || continue
            /usr/libexec/PlistBuddy -c "Delete :$k" "$AE_PLIST" >/dev/null 2>&1 \
                && echo "cleared plugin cache key: $k"
        done
    else
        echo "no plugin cache keys present"
    fi
else
    echo "no plugin cache file at $AE_PLIST"
fi

if [ "$disk" -eq 1 ]; then
    if [ -d "$AE_DISK_CACHE" ]; then
        rm -rf "${AE_DISK_CACHE:?}"/*
        echo "emptied disk cache: $AE_DISK_CACHE"
    else
        echo "no disk cache folder at $AE_DISK_CACHE"
    fi
fi

echo
echo "Launching ($want)..."
ae_launch "$want" "$@" || exit 1
echo "AE is rescanning every plugin, so this launch is slower than usual."
