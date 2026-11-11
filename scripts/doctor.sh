#!/bin/bash
# Read-only report on this Mac's After Effects 2022 setup. Changes nothing.
#
#   ./doctor.sh

set -u
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

row() { printf '  %-26s %s\n' "$1" "$2"; }

echo "== System =="
row "macOS" "$(sw_vers -productVersion)"
row "Chip" "$(uname -m)"
if have_rosetta; then
    row "Rosetta 2" "installed"
else
    row "Rosetta 2" "NOT installed (softwareupdate --install-rosetta)"
fi

echo
echo "== After Effects =="
if [ -x "$AE_BIN" ]; then
    ver=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$AE_APP/Contents/Info.plist" 2>/dev/null)
    row "App" "$AE_APP"
    row "Version" "${ver:-unknown}"
    row "Architectures" "$(lipo -archs "$AE_BIN" 2>/dev/null || echo unknown)"
else
    row "App" "NOT FOUND at $AE_APP (set AE_APP)"
fi

pid="$(ae_pid)"
if [ -n "$pid" ]; then
    row "Running" "pid $pid, code type: $(ae_mode "$pid")"
else
    row "Running" "no"
fi

echo
echo "== Startup warnings (00 = hidden, 01 or absent = shown) =="
if [ -f "$AE_PREFS_TXT" ]; then
    for key in "Running on Rosetta" "Incompatible plugins warning"; do
        val=$(tr '\r' '\n' < "$AE_PREFS_TXT" | grep -F "\"$key\" = " | head -1 | sed 's/.*= //')
        row "$key" "${val:-absent}"
    done
else
    row "Prefs file" "not found (AE has not been launched yet?)"
fi

echo
echo "== Caches =="
if [ -f "$AE_PLIST" ]; then
    n=$(plutil -convert xml1 -o - "$AE_PLIST" 2>/dev/null | grep -c '<key>PluginCache')
    row "Plugin cache keys" "$n"
else
    row "Plugin cache keys" "none (no plist yet)"
fi
if [ -d "$AE_DISK_CACHE" ]; then
    row "Disk cache" "$(du -sh "$AE_DISK_CACHE" 2>/dev/null | awk '{print $1}') in $AE_DISK_CACHE"
else
    row "Disk cache" "no folder at the default location"
fi

echo
echo "== CEP panels =="
for v in 11 12; do
    row "CSXS.$v PlayerDebugMode" "$(defaults read "com.adobe.CSXS.$v" PlayerDebugMode 2>/dev/null || echo unset)"
done

echo
echo "Next: ./plugin-arch.sh shows which plugins need Rosetta."
