#!/bin/bash
# bcc-host-check.sh — why a BCC/Continuum effect fails with AE error (25 :: 3).
#
# "This effect cannot be applied because it cannot be initialized" is AE saying
# the plug-in's global setup returned an error. For Continuum the common cause is
# a host version the installed Continuum line does not support: the bundle is
# still enumerated by AE, then refuses to initialize.
#
# Vendor host ranges (Boris FX release notes, checked 2026-11-10):
#   Continuum 2026 (v19, 2026.0.x) -> AE CC 2023, 2024, 2025
#   Continuum 2025 (v18)           -> AE CC 2023, 2024, 2025
#   Continuum 2024 (v17)           -> AE CC 2021, 2022, 2023, 2024
#
# Usage: ./bcc-host-check.sh

set -u

CONT="/Library/Application Support/Adobe/Common/Plug-ins/7.0/MediaCore/BorisFX/Continuum"
PROBE="$CONT/BCCTemporalBlur.bundle/Contents/Info.plist"
LOGDIR="$HOME/Library/Preferences/Adobe/After Effects"
UNSUPPORTED=0

echo "== Installed Continuum =="
if [ -f "$PROBE" ]; then
  raw=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PROBE" 2>/dev/null | tr -d ' ')
  major=$(echo "$raw" | cut -d. -f1)
  echo "path:    $CONT"
  echo "version: ${raw:-unknown}  (major v${major:-?})"
else
  echo "no Continuum install found at $CONT"
  exit 2
fi

case "$major" in
  19) lo=23; hi=25; line="Continuum 2026 (v19)" ;;
  18) lo=23; hi=25; line="Continuum 2025 (v18)" ;;
  17) lo=18; hi=24; line="Continuum 2024 (v17)" ;;
  *)  lo=0;  hi=0;  line="unknown Continuum line" ;;
esac
echo "vendor range: $line -> AE major ${lo}..${hi}"

echo
echo "== Installed After Effects =="
found=0
for app in /Applications/Adobe\ After\ Effects\ */*.app; do
  [ -d "$app" ] || continue
  case "$app" in *"Render Engine"*) continue ;; esac
  found=1
  v=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist" 2>/dev/null)
  m=${v%%.*}
  if [ "$lo" -ne 0 ] && [ "$m" -ge "$lo" ] && [ "$m" -le "$hi" ]; then
    state="SUPPORTED"
  else
    state="NOT SUPPORTED"
    UNSUPPORTED=1
  fi
  printf 'AE %-6s %-13s %s\n' "$v" "($state)" "$app"
done
[ "$found" -eq 1 ] || echo "no AE installation under /Applications"

echo
echo "== AE plugin log: is the BCC bundle being skipped? =="
log=""
pid=$(pgrep -f "MacOS/After Effects$" | head -1)
if [ -n "$pid" ]; then
  comm=$(ps -p "$pid" -o comm=)
  appdir=${comm%/Contents/MacOS/*}
  if [ -f "$appdir/Contents/Info.plist" ]; then
    ver=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$appdir/Contents/Info.plist" 2>/dev/null)
    [ -f "$LOGDIR/$ver/Plugin Loading.log" ] && log="$LOGDIR/$ver/Plugin Loading.log"
  fi
fi
if [ -z "$log" ]; then
  for f in "$LOGDIR"/*/"Plugin Loading.log"; do
    [ -f "$f" ] && log="$f"
  done
fi
if [ -n "$log" ]; then
  echo "log: $log"
  grep -A2 "Loading .*Continuum/BCCTemporalBlur.bundle" "$log" | tail -4
  echo
  echo "Continuum bundles in this log:"
  awk '/^Loading .*\/BorisFX\/Continuum\//{n=$0; getline a; getline b; if (b ~ /marked as Ignore/) {ig++; if (ig<=5) print "  IGNORED  " n} else lo++} END {printf "  ignored=%d loaded=%d\n", ig+0, lo+0}' "$log"
else
  echo "no Plugin Loading.log found under $LOGDIR"
fi

echo
echo "== Running AE: is the BCC core engine mapped? =="
pid=$(pgrep -f "MacOS/After Effects$" | head -1)
if [ -n "$pid" ]; then
  echo "pid: $pid"
  if vmmap "$pid" 2>/dev/null | grep -q "BorisFX/Lib/BCCAE/BCC Common"; then
    echo "BCC Common: mapped"
  else
    echo "BCC Common: NOT mapped (plugin init did not reach the engine)"
  fi
else
  echo "After Effects is not running"
fi

echo
if [ "$UNSUPPORTED" -eq 1 ]; then
  echo "VERDICT: host/plug-in version mismatch — error (25 :: 3) is Continuum refusing this AE."
  echo "Fix: install the newest Continuum line that supports your AE (v17/Continuum 2024 for AE 2022),"
  echo "     or install AE 2023+ and keep Continuum 2026."
  exit 1
fi
echo "VERDICT: installed Continuum line lists this AE as supported."
exit 0
