#!/usr/bin/env python3
"""Show or hide two After Effects 22.6 startup warnings.

  rosetta  "Running on Rosetta"            shown every launch under Rosetta
  plugins  "Incompatible plugins warning"  shown in native mode when Intel-only
                                           plugins are installed

Both live in the "Application Warning Preference Section" of AE's prefs file as
a one-byte value: 01 = show, 00 = hide (the same thing the dialog's own
"don't show again" choice writes). The file is CR-delimited text, not a plist:

  ~/Library/Preferences/Adobe/After Effects/22.6/Adobe After Effects 22.6 Prefs.txt

Usage:
  ./ae-warnings.py --check
  ./ae-warnings.py --hide rosetta
  ./ae-warnings.py --hide plugins
  ./ae-warnings.py --show rosetta
  ./ae-warnings.py --hide rosetta --force    # allow while AE is running

Quit After Effects first: it rewrites this file when it exits. A timestamped
backup is made before every write.
"""
import argparse
import datetime
import os
import re
import shutil
import subprocess
import sys

PREF = os.environ.get("AE_PREFS_TXT") or os.path.expanduser(
    "~/Library/Preferences/Adobe/After Effects/22.6/"
    "Adobe After Effects 22.6 Prefs.txt"
)
SECTION = '["Application Warning Preference Section"]'
KEYS = {
    "rosetta": "Running on Rosetta",
    "plugins": "Incompatible plugins warning",
}


def ae_running():
    try:
        out = subprocess.run(
            ["ps", "-axo", "command"], capture_output=True, text=True, timeout=15
        ).stdout
    except Exception:
        return False
    return "Adobe After Effects 2022.app/Contents/MacOS" in out


def read_bytes(path):
    with open(path, "rb") as f:
        return f.read()


def line_re(key):
    return re.compile(rb'\t"' + re.escape(key.encode()) + rb'" = ([^\r]*)')


def split_section(data):
    """Return (header_start, body_end) for the section, or (None, None)."""
    hdr = data.find(SECTION.encode() + b"\r")
    if hdr < 0:
        return None, None
    nxt = data.find(b"\r[", hdr + len(SECTION))
    return hdr, (len(data) if nxt < 0 else nxt + 1)


def current_value(data, key):
    hdr, end = split_section(data)
    if hdr is None:
        return None
    m = line_re(key).search(data[hdr:end])
    return None if not m else m.group(1).decode()


def set_value(data, key, value):
    hdr, end = split_section(data)
    line = b'\t"' + key.encode() + b'" = ' + value.encode() + b"\r"
    if hdr is None:
        # append a new section at EOF
        if data and not data.endswith(b"\r"):
            data += b"\r"
        return data + SECTION.encode() + b"\r" + line
    body = data[hdr:end]
    pattern = line_re(key)
    if pattern.search(body):
        new_body = pattern.sub(lambda _: line[:-1], body, count=1)
    else:
        # insert at the end of the section body, before the blank line /
        # next section header (never directly after the header)
        ins = end
        if data[ins - 1:ins] == b"\r" and ins >= 2 and data[ins - 2:ins - 1] == b"\r":
            ins -= 1  # keep the blank separator line in place
        new_body = body[:ins - hdr] + line + body[ins - hdr:]
    return data[:hdr] + new_body + data[end:]


def main():
    ap = argparse.ArgumentParser(description="Show or hide AE 22.6 startup warnings.")
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--check", action="store_true", help="print current values")
    g.add_argument("--hide", choices=sorted(KEYS), help="stop showing a warning")
    g.add_argument("--show", choices=sorted(KEYS), help="show a warning again")
    ap.add_argument("--force", action="store_true", help="write even if AE is running")
    args = ap.parse_args()

    if not os.path.exists(PREF):
        sys.exit(f"Prefs file not found (launch AE once first): {PREF}")

    data = read_bytes(PREF)
    print(f"file: {PREF}")
    for name, key in sorted(KEYS.items()):
        val = current_value(data, key)
        state = {"00": "hidden", "01": "shown"}.get(val, "shown (absent)" if val is None else val)
        print(f"  {name:8} {key!r}: {state}")

    if args.check:
        return

    name = args.hide or args.show
    key = KEYS[name]
    value = "00" if args.hide else "01"

    if ae_running() and not args.force:
        sys.exit("After Effects is running. Quit it first, or pass --force.")

    new = set_value(data, key, value)
    if new == data:
        print("already set; nothing written")
        return

    stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    backup = f"{PREF}.bak-{stamp}"
    shutil.copy2(PREF, backup)
    tmp = PREF + ".tmp"
    with open(tmp, "wb") as f:
        f.write(new)
    os.replace(tmp, PREF)
    print(f"backup: {backup}")
    print(f"wrote:  {key!r} = {current_value(read_bytes(PREF), key)}")


if __name__ == "__main__":
    main()
