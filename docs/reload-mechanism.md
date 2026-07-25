# Reload Mechanism Design

## Problem

Clicking "Reload" in the power popup killed all user applications —
terminals, Firefox, Dolphin — not just the Quickshell bar process.

## Root Cause

`omd-bar.service`'s systemd cgroup contains user apps launched from the
bar/launcher (terminals, Firefox, tmux, etc.) that inherit the bar's
cgroup. `systemctl stop omd-bar.service` destroys the entire cgroup,
killing everything inside — regardless of `KillMode` (tested: `mixed`,
`process`, `control-group` all kill cgroup children on unit stop).

This was a regression introduced when the stop script switched from
`pkill` (targets only quickshell binaries) to `systemctl stop` (destroys
entire unit cgroup).

## Solution

### pkill, not systemctl stop (scripts/omd-quickshell-stop.sh)

Kill only quickshell processes by command-line pattern:

```sh
pkill -f "/usr/bin/quickshell -p ${omd_root}/"
```

This never touches cgroup siblings. User apps in the bar's cgroup
survive the reload. SIGTERM first, then SIGKILL after 0.3s grace period.

After quickshell processes are dead, clean up transient unit definitions
(`reset-failed`, `rm transient/*.service`) so `omd-restart` can create
fresh units.

### What was tried and abandoned

1. **KillMode=mixed** — doesn't help; systemd still destroys cgroup on
   unit inactive.
2. **KillMode=process** — same; cgroup teardown is independent of
   KillMode.
3. **Cgroup rescue** (move PIDs to a holding scope before stop) —
   fragile, race-prone, didn't reliably work in practice.
4. **Cgroup escape for omd-restart** (re-exec via `systemd-run --scope`)
   — solved the script killing itself, but not user apps.

The pkill approach is what the original script used before the
`systemctl stop` regression. It's simple and correct: reload only
needs to restart quickshell processes, not manage systemd units.

## Files

| File | Role |
|---|---|
| `bin/omd-restart` | Unified reload entry point: stop, start, Hyprland reload |
| `scripts/omd-quickshell-stop.sh` | Stop logic: pkill quickshell, watcher cleanup, unit reset |
| `quickshell/modules/power-indicator/PowerPopup.qml` | Reload button → `omd-restart` |

## Reload flow

```
PowerPopup "Reload" button
  → Quickshell.execDetached(["bash", omd-restart])
    → omd-restart
      → omd_stop_quickshell()
        → pkill quickshell -p <omd_root>/  (SIGTERM, then SIGKILL)
        → pkill watchers (nmcli, cliphist, ...)
        → reset-failed + rm transient unit files
      → start_app omd-bar (systemd-run --unit=omd-bar)
      → start_app omd-polkit
      → start registry-driven app modules
      → hyprctl reload
      → reload-terminals
```

## Known limitations

- `omd-detach` still doesn't reliably create `omd-launched-*` scopes for
  apps launched from the launcher, so user apps remain in the bar's
  cgroup. This is harmless with the pkill approach (cgroup is never
  destroyed during reload), but a future fix should make `omd-detach`
  work correctly for cleaner cgroup isolation.