# Performance Optimization Audit - 2026-07-11

This document tracks the current OMD resource hot spots and the concrete fixes
to apply. The goal is lower idle CPU/RAM, fewer leaked helper processes, and
faster perceived UI response without removing core desktop behavior.

## Current Runtime Snapshot

- `omd-bar.service` is the heaviest Quickshell process: about 600 MB cgroup
  memory after 12 minutes, with `quickshell`, `nmcli monitor`, launched terminal
  processes, `tmux`, voice transcription, and `wl-copy` all in the same cgroup.
- Split Quickshell apps are otherwise moderate:
  - `omd-desktop`: about 81 MB
  - `omd-overview`: about 113 MB
  - `omd-applauncher`: about 82 MB
  - `omd-corners`: about 42 MB
  - `omd-clipboard`: about 72 MB
- There are duplicate clipboard watchers:
  - legacy `wl-paste --type text --watch cliphist store`
  - legacy `wl-paste --type image --watch cliphist store`
  - current `omd-clipboard-store` text and image watchers
- `Network.qml` keeps a long-running `nmcli monitor` and also starts several
  one-shot `nmcli` queries at service initialization.
- Startup logs show repeated `ddcutil detect` activity and I2C lock warnings.
- `OverviewSearch.qml` overlay is no longer loaded; overview search now filters
  workspace cards inline.

## Optimization Plan

### 1. Restart Cleanup For Known Watchers

Status: done

Problem: `omd-restart` avoids killing whole cgroups so user-launched terminals
survive, but Quickshell child watcher processes can also survive. This leaves
old `nmcli monitor` and legacy `wl-paste` processes around.

Fix:
- Kill `nmcli monitor` before restarting Quickshell.
- Kill both current and legacy `wl-paste` clipboard watcher command forms.

Validation:
- Run `omd-restart`.
- `pgrep -a 'nmcli|wl-paste'` should show one `nmcli monitor` and only the
  current two `omd-clipboard-store` watchers.

### 2. Detach User-Launched Apps From Quickshell Cgroups

Status: done

Problem: apps launched from Quickshell inherit the launcher service cgroup. This
inflates `omd-bar.service`/`omd-applauncher.service` memory and makes service
status misleading. It also forces restart logic to avoid normal `systemctl stop`.

Fix:
- Add an `omd-detach` helper that starts commands in a detached transient scope
  when `systemd-run --user --scope` is available, with a `setsid` fallback.
- Route high-volume launches (`AppSearch.launchApp`, terminal/TUI launchers,
  clipboard paste helpers where appropriate) through the helper.

Validation:
- Launch a terminal/app from OMD.
- Confirm it no longer appears under `omd-bar.service` or
  `omd-applauncher.service` cgroups.

### 3. Make Network Wi-Fi Scans On-Demand

Status: done

Problem: the bar needs connection status at idle, not a full AP list. Current
`Network.qml` initializes several external `nmcli` commands, including access
point enumeration, known profile scanning, active name, signal, and wifi radio
status.

Fix:
- Keep lightweight connection type/status checks for the bar icon.
- Defer AP list and known profile scans until the network menu is opened or the
  user explicitly rescans.
- Coalesce active SSID/signal/status into fewer commands where practical.

Validation:
- On shell startup, fewer `nmcli` child processes should appear.
- Opening the network menu still shows available networks.

### 4. Prevent Duplicate Clipboard Watchers

Status: done

Problem: legacy `wl-paste --type ... --watch cliphist store` processes can
coexist with the current `omd-clipboard-store` watchers.

Fix:
- Expand stop cleanup.
- Optionally add a startup guard in `omd-clipboard-store` to kill legacy
  watchers before starting current watchers.

Validation:
- `pgrep -a wl-paste` shows only two current watchers.

### 5. Throttle External Brightness/DDC Detection

Status: done

Problem: `ddcutil detect` runs from multiple Quickshell processes at startup and
can block or emit I2C lock warnings.

Fix:
- Cache DDC detection results in a user-state file with a short TTL.
- Only probe DDC from the display/brightness owner process.

Validation:
- Restart Quickshell and confirm fewer `ddcutil` log lines.

### 6. Reduce Always-On Split Apps

Status: pending

Problem: `omd-applauncher`, `omd-overview`, and `omd-clipboard` are all resident
Quickshell processes. This improves responsiveness, but costs roughly 250 MB RSS
combined.

Fix:
- Keep bar/desktop/corners resident.
- Evaluate launching overview/applauncher/clipboard on demand, or keep resident
  only when latency requires it.

Validation:
- Compare RSS and open latency before/after.

### 7. Overview Screencopy Cost

Status: pending

Problem: overview intentionally keeps its Loader active so ScreencopyViews retain
frames. This avoids black thumbnails but keeps some state resident.

Fix:
- Add a configurable performance mode that unloads heavy overview capture state
  when closed, while keeping the current behavior as the visual default.

Validation:
- Measure overview process RSS before/after with performance mode enabled.

### 8. Remove Hot Startup Warning Loops

Status: done

Problem: recurring QML warnings from startup code make real performance
regressions harder to spot and can add avoidable log churn.

Fix:
- Make `ConflictKiller` parse deterministic two-line process output instead of
  assuming shell separators appear in stdout.
- Make `StyledPopup.active` evaluate to a real bool when no hover target exists.

Validation:
- Restart Quickshell and check startup logs for those warning lines.
