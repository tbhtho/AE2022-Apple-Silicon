#!/bin/bash
# Diagnose and fix the "extension panel is listed but will not open" case.
#
# Symptom: the panel is under Window > Extensions, you click it, nothing opens.
# Usual cause: the extension is unsigned, or its signature no longer matches its
# files, so CEP refuses to start it and logs
#   ERROR Signature verification failed for extension <id>
# Adobe's supported switch for this is PlayerDebugMode=1 for the matching CSXS
# version (AE 2022 = CSXS.11, AE 2024/2025 = CSXS.12).
#
#   ./cep-doctor.sh status   list extensions, flags and signature failures
#   ./cep-doctor.sh fix      set PlayerDebugMode 1 for CSXS 9 to 12
#   ./cep-doctor.sh undo     remove PlayerDebugMode again
#   ./cep-doctor.sh watch    follow the CEP log live
#
# After `fix`, quit After Effects completely (Cmd+Q) and reopen it if the panel
# still does not open: a running AE can keep its old copy of the setting.

set -u

LOG="$HOME/Library/Logs/CSXS/CEP11-AEFT.log"
EXT_DIRS=(
    "/Library/Application Support/Adobe/CEP/extensions"
    "$HOME/Library/Application Support/Adobe/CEP/extensions"
)

status() {
    echo "== Installed extensions =="
    local found=0 dir ext id sig
    for dir in "${EXT_DIRS[@]}"; do
        [ -d "$dir" ] || continue
        for ext in "$dir"/*; do
            [ -f "$ext/CSXS/manifest.xml" ] || continue
            found=1
            id=$(grep -o 'ExtensionBundleId="[^"]*"' "$ext/CSXS/manifest.xml" | head -1 | cut -d'"' -f2)
            if [ -f "$ext/META-INF/signatures.xml" ]; then sig="signature file present"; else sig="UNSIGNED"; fi
            printf '  %-34s %-24s %s\n' "$(basename "$ext")" "$sig" "${id:-?}"
        done
    done
    [ "$found" -eq 1 ] || echo "  none found"

    echo
    echo "== PlayerDebugMode =="
    local v
    for v in 9 10 11 12; do
        printf '  CSXS.%-2s = %s\n' "$v" "$(defaults read "com.adobe.CSXS.$v" PlayerDebugMode 2>/dev/null || echo unset)"
    done

    echo
    echo "== Signature failures in the CEP 11 log =="
    if [ -f "$LOG" ]; then
        local n
        n=$(grep -c "Signature verification failed for extension" "$LOG" 2>/dev/null || true)
        echo "  count: ${n:-0}"
        grep -o "Signature verification failed for extension [^ ]*" "$LOG" | sort | uniq -c | sed 's/^/  /'
    else
        echo "  no log at $LOG"
    fi
}

fix() {
    local v
    for v in 9 10 11 12; do
        defaults write "com.adobe.CSXS.$v" PlayerDebugMode 1
        printf '  CSXS.%-2s = %s\n' "$v" "$(defaults read "com.adobe.CSXS.$v" PlayerDebugMode)"
    done
    echo
    echo "Now open the panel from Window > Extensions. If it still does not open,"
    echo "quit After Effects completely (Cmd+Q) and reopen it."
}

undo() {
    local v
    for v in 9 10 11 12; do
        defaults delete "com.adobe.CSXS.$v" PlayerDebugMode 2>/dev/null && echo "  removed CSXS.$v PlayerDebugMode"
    done
    echo "Done. Unsigned extensions will stop loading on the next launch."
}

watch_log() {
    echo "Watching $LOG. Open the panel now (Ctrl+C to stop)."
    tail -n 0 -F "$LOG" 2>/dev/null
}

case "${1:-status}" in
    status) status ;;
    fix)    fix ;;
    undo)   undo ;;
    watch)  watch_log ;;
    *)      echo "usage: $0 [status|fix|undo|watch]" >&2; exit 2 ;;
esac
