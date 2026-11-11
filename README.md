<h1 align="center">AE 2022 on Apple Silicon</h1>

<p align="center"><b>Keep After Effects 2022 and its older plugins working on a new Mac.</b><br>
Launchers, checks and plain-language notes on Rosetta, plugin caches and the errors that waste an afternoon.</p>

<p align="center">
  <img src="https://img.shields.io/badge/After_Effects-22.6-9999FF.svg" alt="After Effects 22.6">
  <img src="https://img.shields.io/badge/tested_on-macOS_15.5-blue.svg" alt="Tested on macOS 15.5">
  <img src="https://img.shields.io/badge/chip-Apple_Silicon-lightgrey.svg" alt="Chip: Apple Silicon">
  <img src="https://img.shields.io/badge/Intel_plugins-Rosetta_2-orange.svg" alt="Intel plugins run under Rosetta 2">
  <img src="https://img.shields.io/badge/license-GPL--3.0--or--later-green.svg" alt="License: GPL-3.0-or-later">
</p>

<p align="center">
  <img src="assets/plugins-timeline.svg" width="100%" alt="Plugins loaded in After Effects 22.6 on an M3 Mac, drawn as a timeline: BCC Continuum 12.5 loads 302, Sapphire 290, Red Giant Universe 3.3.3 loads 90, Omino 8, Twixtor 8 loads 4. Continuum 2026 and Trapcode 2026.3 are blocked.">
</p>

## Why this exists

After Effects 2022 is the last version a lot of older plugin suites were built for, and most of those suites are Intel-only. AE 2022 itself runs natively on Apple Silicon, but a plugin is loaded into AE's own process, so a native AE cannot load an Intel plugin. On an M-series Mac that shows up as plugins missing from the Effects menu, an "incompatible plugins" warning at startup, effects that fail with `(25 :: 3)`, and panels that are listed but never open.

Nearly all of it comes down to three things: which mode AE was started in, what AE has cached about your plugins, and which versions of a suite are installed side by side. This repo has a script for each.

## Native or Rosetta

AE 2022 can start in two modes. Pick per session.

| | Native (arm64) | Rosetta (x86_64) |
|---|---|---|
| **Starts in** | About 5 seconds | A minute or more while it scans plugins |
| **Loads** | Universal plugins only | Universal and Intel-only plugins |
| **Use it for** | Projects that only use built-in or universal effects | Anything using older suites |
| **Start it with** | `scripts/launch-native.command` | `scripts/launch-rosetta.command` |

A project saved in one mode opens in the other. Effects from plugins that did not load show as missing until you reopen under Rosetta.

The first Rosetta launch is much slower than the rest: macOS translates AE and every Intel plugin once and stores the result, which took more than six minutes on the test machine. Later launches reuse it.

## Getting started

You need an Apple Silicon Mac, After Effects 2022 (22.6) in `/Applications/Adobe After Effects 2022`, and Rosetta 2:

```bash
softwareupdate --install-rosetta --agree-to-license
```

Clone the repo and see where your Mac stands. Both commands only read:

```bash
git clone https://github.com/tbhtho/AE2022-Apple-Silicon.git
cd AE2022-Apple-Silicon/scripts
./doctor.sh          # macOS, Rosetta, AE version, current mode, caches, warnings
./plugin-arch.sh     # which installed plugins need Rosetta
```

Then launch in the mode you need. The `.command` files can also be double-clicked in Finder.

```bash
./launch-rosetta.command "/path/to/project.aep"
```

> [!NOTE]
> If AE is installed somewhere else, set `AE_APP` to the full path of the `.app` before running a script.

## Scripts

| Script | What it does | Changes anything? |
|---|---|---|
| [`launch-rosetta.command`](scripts/launch-rosetta.command) | Starts AE under Rosetta and reports the mode it actually got | No |
| [`launch-native.command`](scripts/launch-native.command) | Starts AE natively | No |
| [`restart-clean.command`](scripts/restart-clean.command) | Quits AE without force-killing, clears every plugin cache key, relaunches. `--native` and `--disk-cache` are optional | Clears caches |
| [`doctor.sh`](scripts/doctor.sh) | One-screen report on the system, AE, caches and warnings | No |
| [`plugin-arch.sh`](scripts/plugin-arch.sh) | Counts native and Intel-only plugins per suite. `--list` names them | No |
| [`ae-warnings.py`](scripts/ae-warnings.py) | Hides or restores the "Running on Rosetta" and "incompatible plugins" startup warnings, with a backup | AE prefs |
| [`cep-doctor.sh`](scripts/cep-doctor.sh) | Finds why an extension panel will not open, and sets `PlayerDebugMode` to fix it. `undo` reverses it | One macOS default |
| [`bcc-host-check.sh`](scripts/bcc-host-check.sh) | Explains a Continuum `(25 :: 3)` error: installed version, supported AE range, engine state | No |

## What was tested

One machine: a MacBook Pro M3 (8 GB) on macOS 15.5 with After Effects 22.6. "Working" means an effect was applied and rendered, or the plugin registered in the running app.

| Plugin | Version | Built for | Mode needed | Result |
|---|---|---|---|---|
| BCC Continuum | 12.5 (2019) | Intel | Rosetta | **Working**, 302 plugins. Needs its own engine set, see [Continuum](#continuum-and-the-25--3-error) |
| Sapphire | 2019 era | Mixed | Rosetta | **Working**, 290 plugins |
| Red Giant Universe | 3.3.3 (2021) | Intel | Rosetta | **Working**, 90 plugins |
| Twixtor | 8 | Intel | Rosetta | **Working** |
| Optical Flares, Twitch | 2019 | Intel | Rosetta | **Working** |
| RSMB, Omino, PixelSorter 2 | 6.x and legacy | Intel | Rosetta | **Working** |
| FXConsole, Signal | 1.0.5, 1.2.3 | Universal | Either | **Working** |
| Flow (panel) | 1.4.2 | CEP 11 | Either | **Working** after `cep-doctor.sh fix` |
| Continuum 2026 | 19.0.1 | Universal | | Does not support AE 2022, and breaks 12.5 if installed beside it |
| Trapcode, Red Giant VFX | 2026.3 | Universal | | Not tested: needs a Maxon One account |

This is about loading and rendering. You need your own licence for After Effects and for each plugin; nothing here installs, activates or unlocks software.

## Things worth knowing

### Check the mode, do not assume it

The launchers start the AE binary directly through `arch -x86_64`. `open --arch x86_64` and `arch -x86_64 open -a` look equivalent, and in testing they produced a native process. If you launch another way, check:

```bash
vmmap $(pgrep -f "MacOS/After Effects" | head -1) | grep "Code Type"
```

`X86-64 (translated)` is Rosetta, `ARM64` is native. Activity Monitor shows the same in its Kind column. To make Rosetta the default for Dock and Finder launches, select the app, choose File > Get Info, and tick **Open using Rosetta**.

### Two caches hide your changes

Most "I fixed it and nothing changed" moments are one of these.

**Plugin cache.** AE scans plugins only at launch and remembers a verdict for each one in `~/Library/Preferences/com.Adobe.After Effects.22.6.plist`. There are two sets, `PluginCache` for Rosetta and `PluginCache.ARM64.*` for native, and clearing only one leaves the other stale. After installing, removing or moving plugins, run `restart-clean.command`.

**Disk cache.** AE keeps rendered frames in `~/Library/Caches/Adobe/After Effects/22.6`. A frame rendered before a plugin change can keep appearing in the viewer, which makes a working fix look like it failed. Empty it from Preferences > Media & Disk Cache, or run `restart-clean.command --disk-cache`.

### Where AE 2022 looks for plugins

| Folder | Typical contents |
|---|---|
| `/Applications/Adobe After Effects 2022/Plug-Ins/` | Plugins installed for this version only |
| `/Library/Application Support/Adobe/Common/Plug-ins/7.0/MediaCore/` | Shared by AE and Premiere, all users. Most installers use this |
| `~/Library/Application Support/Adobe/Common/Plug-ins/7.0/MediaCore/` | The same, for your user only |

It does not scan the old `CS6/MediaCore` folder. A plugin an old installer put there has to be moved to `7.0/MediaCore`.

### A log line that is not an error

`Plugin Loading.log` in AE's preferences folder is full of lines reading `No loaders recognized this plugin, so the plugin is set to Ignore.` AE writes that for some of its own stock effects and for third-party plugins that load and render correctly. Judge a plugin by whether it appears in the Effects menu and applies.

### Continuum and the (25 :: 3) error

"This effect cannot be applied because it cannot be initialized (25 :: 3)" means the plugin was found and then refused to start. With Boris FX Continuum there are two usual causes.

**The Continuum version does not support AE 2022.** Recent releases start at AE 2023. Ranges below are from the Boris FX release notes as of November 2026, and `bcc-host-check.sh` reads your install and tells you if this is the problem.

| Continuum | After Effects |
|---|---|
| 2026 (v19) | 2023, 2024, 2025 |
| 2025 (v18) | 2023, 2024, 2025 |
| 2024 (v17) | 2021, 2022, 2023, 2024 |

**Two Continuum versions are sharing one engine.** Continuum plugins are thin wrappers around a shared engine in `/Library/Application Support/BorisFX/Lib/`. Installing Continuum 2026 beside 12.5 on the test machine produced `(25 :: 3)` on every BCC effect. The layout that works is 12.5 on its own: its plugins in AE's `Plug-Ins/Effects`, its engine in `BorisFX/Lib/BCC12BitDepthSupport`, no 2026 engine set in `BorisFX/Lib/BCCAE`, and AE under Rosetta. Uninstall the newer version, or move its folders out of the scan paths, then run `restart-clean.command`.

The same rule holds for other suites: keep one version installed at a time, the newest one whose release notes list AE 2022.

### Panels that will not open

Panels such as Flow are CEP extensions. When one is listed under Window > Extensions but nothing opens, CEP has usually rejected its signature. `cep-doctor.sh status` shows the evidence and `cep-doctor.sh fix` sets `PlayerDebugMode`, Adobe's developer switch that lets unsigned extensions load. It applies to every extension, so only use it with extensions you got from their author.

### Old installers that refuse to run

Some Intel-era installers check the processor type and stop with "The current OS X version is not supported". Running the installer's inner script under Rosetta makes the check pass. This was needed for Twixtor 7:

```bash
sudo arch -x86_64 "/path/to/Installer.app/Contents/MacOS/installbuilder.sh"
```

## Troubleshooting

| Symptom | Fix |
|---|---|
| A whole suite is missing from the Effects menu | AE is running natively. Quit and use `launch-rosetta.command` |
| A suite is still missing under Rosetta | `restart-clean.command`, then check it is in a folder AE scans |
| "Plugins are not compatible with this version" at startup | Expected in native mode. Use Rosetta, or `ae-warnings.py --hide plugins` |
| "Running on Rosetta" warning on every launch | `ae-warnings.py --hide rosetta` with AE closed |
| Launched with Rosetta but Intel plugins are missing | The launch fell back to native. Check with `doctor.sh` |
| `(25 :: 3)` on a Continuum effect | `bcc-host-check.sh`, then see [Continuum](#continuum-and-the-25--3-error) |
| The viewer shows the old result after a plugin change | `restart-clean.command --disk-cache` |
| A panel is listed but does not open | `cep-doctor.sh fix`, then restart AE if needed |
| A script says AE did not quit | A dialog is open in AE. Dismiss it, save, and run the script again |
| AE opens to a small dialog and no main window | A prefs file was damaged by a hand edit. Restore the `.bak-` copy next to it, or hold Cmd+Option+Shift at launch to reset preferences |

## Limits

These results come from one Mac, one macOS version and one set of plugin builds, and a different setup may behave differently. If it does, an issue with the output of `doctor.sh` and the exact error text is the most useful report.

Rosetta 2 is the piece all of this rests on. Apple has said it will keep Rosetta generally available through macOS 27 and scale it back after that, so treat an Intel-only plugin setup as something with an end date.

## Licence

Free software under the GNU General Public License, version 3 or later. See [LICENSE](LICENSE). Copyright (C) 2026 tbhtho.

This project is not affiliated with or endorsed by Adobe, Apple, Boris FX, Maxon, RE:Vision Effects, Video Copilot or any other vendor named here. Product names are trademarks of their owners.
