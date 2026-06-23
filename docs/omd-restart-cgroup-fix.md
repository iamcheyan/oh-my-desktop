# omd-restart cgroup bug fix

## Problem

When `omd-restart` was run, applications launched through the Quickshell applauncher
(`Quickshell.execDetached`) were killed along with the Quickshell processes. This
caused workspaces that only contained those launched apps to disappear entirely.

## Root Cause

`omd-restart` uses `systemd-run --user` to start Quickshell as a transient systemd
service. systemd's default `KillMode` is `control-group`, meaning `systemctl stop`
kills **all processes in the service's cgroup** — not just the main process.

`Quickshell.execDetached` launches child processes that remain in the same cgroup as
the parent Quickshell process. When `systemctl stop omd-applauncher.service` runs
during restart, systemd kills the entire cgroup including:

- The Quickshell process itself
- Any applications launched via `execDetached` (kitty, kaddressbook, filelight, etc.)

Since these apps were the only windows on certain workspaces, Hyprland subsequently
destroyed those empty workspaces, making it appear that the workspaces "disappeared."

## Timeline

1. User opens apps via applauncher → apps become children of Quickshell's cgroup
2. User runs `omd-restart`
3. `systemctl --user stop omd-applauncher.service` → kills entire cgroup
4. All launched apps are killed
5. Hyprland destroys now-empty workspaces

## Fix

Two changes to `bin/omd-restart`:

### 1. `KillMode=process`

```
systemd-run --user --property=KillMode=process ...
```

This tells systemd to only kill the main process (quickshell) when stopping the
service, leaving child processes (launched apps) alive.

### 2. Clean up transient unit files

```
systemctl --user stop "$app.service"
systemctl --user reset-failed "$app.service"
rm -f "/run/user/$(id -u)/systemd/transient/$app.service"
systemctl --user daemon-reload
```

Transient service unit files can persist in `/run/user/*/systemd/transient/`.
Without cleanup, `systemd-run` fails with "Unit already loaded or has a fragment
file" on consecutive restarts. The fix removes stale unit files and triggers
`daemon-reload` before creating new services.

## Verification

Tested by launching multiple apps across different workspaces (kaddressbook, filelight,
gnome-disks), running `omd-restart`, and confirming:
- All workspaces preserved
- All launched apps survived
- Quickshell restarted cleanly

## Related

- `systemd.service(5)` — `KillMode` documentation
- `Quickshell.execDetached` — forked processes inherit the parent's cgroup
