# Reload Mechanism Design

## Problem

Clicking "Reload" in the power popup killed all user applications —
terminals, Firefox, Dolphin — not just the Quickshell bar process.

## Root Cause

`omd-bar.service`'s systemd cgroup contained user apps launched from the
bar/launcher (terminals, Firefox, tmux, etc.). `omd-detach` was supposed
to move launched apps into separate `omd-launched-*` scopes, but in
practice those scopes were never created — apps stayed in the bar's
cgroup.

`systemctl stop omd-bar.service` destroys the entire cgroup. systemd
cleans up all processes in a cgroup when the unit becomes inactive,
**regardless of `KillMode`** (tested: `mixed`, `process`,
`control-group` — all kill cgroup children on unit stop).

Journal evidence (reload at 19:57:23):

```
omd-bar.service: Killing process 76025 (tmux: server) with signal SIGKILL
omd-bar.service: Killing process 71015 (RDD Process) with signal SIGKILL
omd-bar.service: Killing process 71936 (WebExtensions) with signal SIGKILL
```

## Solution

### Cgroup child rescue (scripts/omd-quickshell-stop.sh)

Before stopping `omd-bar.service`, move all non-Quickshell PIDs from its
cgroup to a transient holding scope:

1. Read `omd-bar.service` cgroup path via `systemctl show -p ControlGroup`
2. Create a holding scope (`omd-survivors-<timestamp>`) kept alive by
   `sleep infinity` with `KillMode=process`
3. Read `cgroup.procs` and write each non-quickshell PID into the
   holding scope's `cgroup.procs` (kernel moves the process)
4. Stop all OMD units — user apps are safe in the holding scope

### Cgroup escape for omd-restart itself (bin/omd-restart)

`omd-restart` is spawned by the bar's `Quickshell.execDetached`, so it
runs inside `omd-bar.service`'s cgroup. Stopping the bar would kill the
reload script before `start_app` runs.

At the top of `omd-restart`, detect if we're inside an `omd-*` service
cgroup (`/proc/self/cgroup`). If so, re-exec via
`systemd-run --user --scope --unit=omd-restart-scope` into a fresh
cgroup. `OMD_ALREADY_ESCAPED=1` breaks the re-exec loop.

### start_app hardening (bin/omd-restart)

- **Skip if already active**: if the unit is `active` or `activating`
  (e.g. systemd auto-restart in progress), don't create a duplicate.
- **KillMode=control-group** for new units: the new unit starts with
  only the Quickshell process — no user apps — so `control-group` is
  safe and ensures clean teardown on next reload.

## Files

| File | Role |
|---|---|
| `bin/omd-restart` | Unified reload entry point: cgroup escape, stop, start, Hyprland reload |
| `scripts/omd-quickshell-stop.sh` | Stop logic: rescue cgroup children, stop units, orphan cleanup |
| `quickshell/modules/power-indicator/PowerPopup.qml` | Reload button → `omd-restart` |

## Reload flow

```
PowerPopup "Reload" button
  → Quickshell.execDetached(["bash", omd-restart])
    → omd-restart detects cgroup = omd-bar.service
    → exec systemd-run --scope (escape cgroup)
      → omd-restart (in fresh scope)
        → omd_stop_quickshell()
          → move user apps to omd-survivors-<ts> scope
          → systemctl stop omd-bar, omd-polkit, omd-overview, ...
        → start_app omd-bar (new unit, KillMode=control-group)
        → start_app omd-polkit
        → start registry-driven app modules
        → hyprctl reload
        → reload-terminals
```

## Known limitations

- The holding scope (`omd-survivors-*`) stays alive until the next
  reboot or manual `systemctl --user stop`. It holds relocated PIDs
  via `sleep infinity`. Over many reloads, stale survivor scopes
  accumulate but are harmless (empty after apps are closed).
- `omd-detach` still doesn't reliably create `omd-launched-*` scopes
  for apps launched from the launcher. The rescue mechanism is a
  safety net, not a fix for the root cause. A future fix should make
  `omd-detach` work correctly so apps never enter the bar's cgroup.