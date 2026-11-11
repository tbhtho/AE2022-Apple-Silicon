#!/bin/bash
# Shared paths and helpers. Sourced by the other scripts; does nothing on its own.
#
# Override either of these in your shell if your install differs:
#   AE_APP      full path to the After Effects .app
#   AE_VERSION  the version folder AE uses for prefs and caches (22.6 for AE 2022)

AE_APP="${AE_APP:-/Applications/Adobe After Effects 2022/Adobe After Effects 2022.app}"
AE_VERSION="${AE_VERSION:-22.6}"

AE_BIN="$AE_APP/Contents/MacOS/After Effects"
AE_DIR="$(dirname "$AE_APP")"
AE_PLIST="$HOME/Library/Preferences/com.Adobe.After Effects.$AE_VERSION.plist"
AE_PREFS_DIR="$HOME/Library/Preferences/Adobe/After Effects/$AE_VERSION"
AE_PREFS_TXT="$AE_PREFS_DIR/Adobe After Effects $AE_VERSION Prefs.txt"
AE_DISK_CACHE="$HOME/Library/Caches/Adobe/After Effects/$AE_VERSION"
AE_LAUNCH_LOG="/tmp/ae2022-launch.log"

# PID of the running After Effects, or nothing.
ae_pid() {
    pgrep -f "$AE_BIN" 2>/dev/null | head -1
}

# How a running process is executing: "ARM64" or "X86-64 (translated)".
ae_mode() {
    vmmap "$1" 2>/dev/null | awk -F: '/Code Type/ { sub(/^[ \t]+/, "", $2); print $2; exit }'
}

# True when Rosetta 2 is installed.
have_rosetta() {
    arch -x86_64 /usr/bin/true >/dev/null 2>&1
}

require_ae() {
    if [ ! -x "$AE_BIN" ]; then
        echo "After Effects was not found at:"
        echo "  $AE_APP"
        echo "Set AE_APP to the full path of your After Effects .app and run this again."
        exit 1
    fi
}

require_rosetta() {
    if ! have_rosetta; then
        echo "Rosetta 2 is not installed. Install it with:"
        echo "  softwareupdate --install-rosetta --agree-to-license"
        exit 1
    fi
}

# Launch AE with the given architecture (x86_64 or arm64) and report the result.
# Starting the binary through `arch` is deliberate: `open --arch x86_64` and
# `arch -x86_64 open -a` have both produced a native process.
ae_launch() {
    local want="$1"
    shift
    nohup arch "-$want" "$AE_BIN" "$@" >"$AE_LAUNCH_LOG" 2>&1 &
    sleep 4
    local pid
    pid="$(ae_pid)"
    if [ -z "$pid" ]; then
        echo "After Effects did not start. See $AE_LAUNCH_LOG"
        return 1
    fi
    echo "After Effects is running (pid $pid), code type: $(ae_mode "$pid")"
}

# Ask a running AE to quit. Never force-kills: a project may be unsaved.
ae_quit() {
    [ -n "$(ae_pid)" ] || return 0
    echo "Asking After Effects to quit. Save your project first if it is open."
    osascript -e "tell application \"$AE_APP\" to quit" >/dev/null 2>&1 || true
    local _
    for _ in $(seq 1 45); do
        [ -n "$(ae_pid)" ] || break
        sleep 1
    done
    if [ -n "$(ae_pid)" ]; then
        echo
        echo "After Effects did not quit. A dialog is probably open on screen."
        echo "Close the dialog, or save and quit by hand, then run this again."
        echo "Nothing was force-killed."
        return 1
    fi
    echo "After Effects closed."
}
