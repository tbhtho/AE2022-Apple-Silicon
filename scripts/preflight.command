#!/bin/bash
# Preflight: find After Effects, check this Mac, then apply the settings that
# make running it under Rosetta work smoothly. Run this once after installing,
# and again after a macOS update.
#
#   ./preflight.command            show what it found, ask, then apply
#   ./preflight.command --check    only report, change nothing
#   ./preflight.command --yes      apply without asking
#   ./preflight.command --panels   also allow unsigned extension panels (CEP)
#   ./preflight.command --launch   start AE under Rosetta when done
#
# What it can change, and nothing else:
#   - install Rosetta 2 if it is missing
#   - hide the "Running on Rosetta" and "incompatible plugins" startup warnings
#   - clear AE's plugin cache so the next launch rescans every plugin
#   - with --panels: set PlayerDebugMode so unsigned panels can open
#
# It never touches the After Effects app, your plugins or your projects.

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"

check_only=0
assume_yes=0
panels=0
launch=0
for arg in "$@"; do
    case "$arg" in
        --check)  check_only=1 ;;
        --yes)    assume_yes=1 ;;
        --panels) panels=1 ;;
        --launch) launch=1 ;;
        -h|--help) sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "unknown option: $arg" >&2; exit 2 ;;
    esac
done

ok()   { printf '  ok      %s\n' "$*"; }
todo() { printf '  change  %s\n' "$*"; }
note()  { printf '  note    %s\n' "$*"; }
stop() { printf '  STOP    %s\n' "$*"; }

echo "AE 2022 on Apple Silicon: preflight"
echo

# ---------------------------------------------------------------- system ----
echo "== This Mac =="
os="$(sw_vers -productVersion)"
os_major="${os%%.*}"
if [ "$(sysctl -n hw.optional.arm64 2>/dev/null)" != "1" ]; then
    ok "macOS $os on an Intel Mac"
    echo
    echo "Intel Macs run Intel plugins directly. You do not need this toolkit."
    exit 0
fi
ok "macOS $os on Apple Silicon"

if [ "$os_major" -ge 28 ] 2>/dev/null; then
    stop "macOS $os_major no longer runs Intel-only code through Rosetta."
    echo
    echo "Intel plugins cannot load on this macOS version. They need macOS 27 or earlier."
    exit 1
fi
[ "$os_major" -eq 27 ] 2>/dev/null && note "macOS 27 is the last version with full Rosetta. Do not update this Mac to macOS 28."

# --------------------------------------------------------- After Effects ----
echo
echo "== After Effects =="
ae_version_of() {
    /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$1/Contents/Info.plist" 2>/dev/null
}

picked="${AE_APP:-}"
if [ -z "$picked" ]; then
    best_rank=99
    for app in /Applications/Adobe\ After\ Effects\ */Adobe\ After\ Effects\ *.app; do
        [ -d "$app" ] || continue
        case "$app" in *"Render Engine"*) continue ;; esac
        v="$(ae_version_of "$app")"
        m="${v%%.*}"
        case "$m" in
            22) rank=1 ;;
            23) rank=2 ;;
            *)  rank=50 ;;
        esac
        printf '  found   After Effects %s (%s)\n' "$((2000 + ${m:-0}))" "${v:-unknown version}"
        if [ "$rank" -lt "$best_rank" ]; then
            best_rank="$rank"
            picked="$app"
        fi
    done
fi

if [ -z "$picked" ] || [ ! -d "$picked" ]; then
    stop "No After Effects found in /Applications."
    echo
    echo "Install After Effects 2022, or set AE_APP to the full path of the .app."
    exit 1
fi

full="$(ae_version_of "$picked")"
major="${full%%.*}"
if [ -z "$major" ]; then
    stop "Could not read the version of: $picked"
    exit 1
fi
if [ "$major" -ge 24 ] 2>/dev/null; then
    stop "After Effects $((2000 + major)) ($full) cannot run under Rosetta."
    echo
    echo "Adobe removed Rosetta support in version 24.0. Intel plugins need"
    echo "After Effects 2022 or 2023 installed alongside it."
    exit 1
fi

export AE_APP="$picked"
export AE_VERSION="$(printf '%s' "$full" | cut -d. -f1,2)"
. "$HERE/lib.sh"
ok "using After Effects $((2000 + major)) ($full)"
printf '          %s\n' "$AE_APP"

running="$(ae_pid)"
[ -n "$running" ] && note "After Effects is open (pid $running, $(ae_mode "$running"))"

# ---------------------------------------------------------------- checks ----
echo
echo "== Settings =="

need_rosetta=0
if have_rosetta; then
    ok "Rosetta 2 is installed"
else
    need_rosetta=1
    todo "install Rosetta 2 (accepts Apple's Rosetta licence for you)"
fi

pref_value() {
    tr '\r' '\n' < "$AE_PREFS_TXT" 2>/dev/null | grep -F "\"$1\" = " | head -1 | sed 's/.*= //'
}

# python3 on a Mac without the developer tools is a stub that opens an
# installer dialog, so only use it when the tools are really there.
have_python=0
py="$(command -v python3 2>/dev/null)"
if [ -n "$py" ]; then
    if [ "$py" != "/usr/bin/python3" ] || xcode-select -p >/dev/null 2>&1; then
        have_python=1
    fi
fi

hide_rosetta=0
hide_plugins=0
if [ ! -f "$AE_PREFS_TXT" ]; then
    note "no preferences yet. Open After Effects once, quit it, then run this again"
else
    if [ "$(pref_value "Running on Rosetta")" = "00" ]; then
        ok "\"Running on Rosetta\" warning is hidden"
    else
        hide_rosetta=1
        todo "hide the \"Running on Rosetta\" startup warning"
    fi
    if [ "$(pref_value "Incompatible plugins warning")" = "00" ]; then
        ok "\"incompatible plugins\" warning is hidden"
    else
        hide_plugins=1
        todo "hide the \"incompatible plugins\" startup warning"
    fi
    if [ $((hide_rosetta + hide_plugins)) -gt 0 ] && [ "$have_python" -eq 0 ]; then
        hide_rosetta=0
        hide_plugins=0
        note "the warnings need python3 to change. Install it with: xcode-select --install"
    fi
fi

cache_keys=0
if [ -f "$AE_PLIST" ]; then
    cache_keys="$(plutil -convert xml1 -o - "$AE_PLIST" 2>/dev/null | grep -c '<key>PluginCache')"
fi
if [ "${cache_keys:-0}" -gt 0 ] 2>/dev/null; then
    todo "clear the plugin cache ($cache_keys keys) so the next launch rescans"
else
    cache_keys=0
    ok "plugin cache is already clear"
fi

set_panels=0
debug_mode="$(defaults read com.adobe.CSXS.11 PlayerDebugMode 2>/dev/null || echo unset)"
if [ "$debug_mode" = "1" ]; then
    ok "unsigned extension panels are allowed (PlayerDebugMode 1)"
elif [ "$panels" -eq 1 ]; then
    set_panels=1
    todo "allow unsigned extension panels (PlayerDebugMode 1)"
else
    note "unsigned panels are blocked. Add --panels if a panel will not open"
fi

# Things this script only reports.
if [ -d "/Library/Application Support/BorisFX/Lib/BCCAE" ] &&
   [ -d "/Library/Application Support/BorisFX/Lib/BCC12BitDepthSupport" ]; then
    note "two Continuum engine sets are installed. That causes the (25 :: 3) error, see the README"
fi
for old in "/Library/Application Support/Adobe/Common/Plug-ins/CS6/MediaCore" \
           "$HOME/Library/Application Support/Adobe/Common/Plug-ins/CS6/MediaCore"; do
    if [ -d "$old" ] && [ -n "$(ls -A "$old" 2>/dev/null)" ]; then
        note "plugins in a folder AE $((2000 + major)) does not scan: $old"
    fi
done

changes=$((need_rosetta + hide_rosetta + hide_plugins + set_panels))
[ "$cache_keys" -gt 0 ] && changes=$((changes + 1))

echo
if [ "$changes" -eq 0 ]; then
    echo "Nothing to change. This Mac is ready."
    [ "$launch" -eq 1 ] && exec "$HERE/launch-rosetta.command"
    echo "Start After Effects with: ./launch-rosetta.command"
    exit 0
fi

if [ "$check_only" -eq 1 ]; then
    echo "$changes change(s) would be made. Run without --check to apply them."
    exit 0
fi

needs_ae_closed=$((hide_rosetta + hide_plugins))
[ "$cache_keys" -gt 0 ] && needs_ae_closed=$((needs_ae_closed + 1))
if [ -n "$running" ] && [ "$needs_ae_closed" -gt 0 ]; then
    echo "After Effects is open. Save your work, quit it, then run this again."
    echo "Nothing was changed."
    exit 1
fi

if [ "$assume_yes" -eq 0 ]; then
    printf 'Apply the %s change(s) marked above? [y/N] ' "$changes"
    read -r answer
    case "$answer" in
        y|Y|yes|YES) ;;
        *) echo "Nothing was changed."; exit 0 ;;
    esac
fi

# ----------------------------------------------------------------- apply ----
echo
echo "== Applying =="
failed=0

if [ "$need_rosetta" -eq 1 ]; then
    if softwareupdate --install-rosetta --agree-to-license >/dev/null 2>&1 && have_rosetta; then
        ok "Rosetta 2 installed"
    else
        failed=$((failed + 1))
        stop "Rosetta 2 did not install. Try: softwareupdate --install-rosetta"
    fi
fi

hide_warning() {
    if AE_PREFS_TXT="$AE_PREFS_TXT" python3 "$HERE/ae-warnings.py" --hide "$1" >/dev/null 2>&1; then
        ok "$2 warning hidden"
    else
        failed=$((failed + 1))
        stop "could not hide the $2 warning. Run: ./ae-warnings.py --hide $1"
    fi
}
[ "$hide_rosetta" -eq 1 ] && hide_warning rosetta "\"Running on Rosetta\""
[ "$hide_plugins" -eq 1 ] && hide_warning plugins "\"incompatible plugins\""

if [ "$cache_keys" -gt 0 ]; then
    plutil -convert xml1 -o - "$AE_PLIST" 2>/dev/null \
        | grep -o '<key>PluginCache[^<]*</key>' \
        | sed 's/<[^>]*>//g' \
        | while IFS= read -r k; do
              [ -n "$k" ] || continue
              /usr/libexec/PlistBuddy -c "Delete :$k" "$AE_PLIST" >/dev/null 2>&1
          done
    ok "plugin cache cleared"
fi

if [ "$set_panels" -eq 1 ]; then
    for v in 9 10 11 12; do
        defaults write "com.adobe.CSXS.$v" PlayerDebugMode 1
    done
    ok "unsigned extension panels allowed"
fi

echo
if [ "$failed" -gt 0 ]; then
    echo "$failed step(s) did not complete. See the STOP lines above."
    exit 1
fi

echo "Done. This Mac is ready."
if [ "$launch" -eq 1 ]; then
    exec "$HERE/launch-rosetta.command"
fi
echo "Start After Effects with: ./launch-rosetta.command"
echo "The first launch under Rosetta is slow while every plugin is scanned."
