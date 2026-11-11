#!/bin/bash
# Report the architecture of every installed After Effects plugin, grouped by
# suite, so you can see which ones only load under Rosetta. Read-only.
#
#   ./plugin-arch.sh           summary per suite
#   ./plugin-arch.sh --list    also list every Intel-only plugin

set -u
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

list=0
[ "${1:-}" = "--list" ] && list=1

ROOTS=(
    "$AE_DIR/Plug-Ins"
    "/Library/Application Support/Adobe/Common/Plug-ins/7.0/MediaCore"
    "$HOME/Library/Application Support/Adobe/Common/Plug-ins/7.0/MediaCore"
)

# Prints: kind <tab> suite <tab> path-relative-to-root
scan_root() {
    local root="$1" b exe f archs kind rel suite
    [ -d "$root" ] || return 0
    find "$root" \( -name '*.plugin' -o -name '*.bundle' \) -type d -prune -print 2>/dev/null |
    while IFS= read -r b; do
        exe=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$b/Contents/Info.plist" 2>/dev/null)
        f="$b/Contents/MacOS/$exe"
        if [ -z "$exe" ] || [ ! -f "$f" ]; then
            f=$(find "$b/Contents/MacOS" -maxdepth 1 -type f 2>/dev/null | head -1)
        fi
        [ -n "$f" ] && [ -f "$f" ] || continue
        archs=$(lipo -archs "$f" 2>/dev/null)
        case " $archs " in
            *" arm64 "*|*" arm64e "*) kind="native" ;;
            *" x86_64 "*)             kind="rosetta" ;;
            *)                        kind="unknown" ;;
        esac
        rel="${b#"$root"/}"
        suite="${rel%%/*}"
        [ "$suite" = "$rel" ] && suite="(top level)"
        printf '%s\t%s\t%s\n' "$kind" "$suite" "$rel"
    done
}

total=0
for root in "${ROOTS[@]}"; do
    [ -d "$root" ] || continue
    rows="$(scan_root "$root")"
    [ -n "$rows" ] || continue
    echo "== $root =="
    printf '%s\n' "$rows" | awk -F'\t' '
        { n[$2]++; k[$2, $1]++ }
        END {
            printf "  %-40s %8s %13s %8s\n", "Suite", "Native", "Rosetta only", "Unknown"
            for (s in n)
                printf "  %-40s %8d %13d %8d\n", substr(s, 1, 40), k[s, "native"], k[s, "rosetta"], k[s, "unknown"]
        }' | { IFS= read -r head; printf '%s\n' "$head"; sort; }
    if [ "$list" -eq 1 ]; then
        echo
        echo "  Intel-only plugins:"
        printf '%s\n' "$rows" | awk -F'\t' '$1 == "rosetta" { print "    " $3 }' | sort
    fi
    echo
    total=$((total + $(printf '%s\n' "$rows" | wc -l)))
done

if [ "$total" -eq 0 ]; then
    echo "No plugins found. Is After Effects installed at $AE_APP ?"
    exit 1
fi

echo "Native       loads in both modes."
echo "Rosetta only loads only when AE runs under Rosetta (launch-rosetta.command)."
