# Clipboard daemon reliability issues

## Summary

The `sumika-clipboard-store` daemon (extension `clipboard`) is a `wl-paste --watch`-based
clipboard history monitor.  Its design is sound and it works correctly when running.
The chronic "can't copy / content doesn't move" failures stem from the daemon being
**killed and restarted on every shell reload**, not from any defect inside the daemon.

## Root causes

All four root causes live in the reload chain (`bin/sumika-restart` +
`scripts/sumika-quickshell-stop.sh` + `hypr/autostart.lua`).

### 1. Reload kills the daemon unconditionally

`scripts/sumika-quickshell-stop.sh:35-43` iterates over **every** registered application
module and runs:

```shell
timeout 3 systemctl --user stop "$app.service"
systemctl --user kill --signal=SIGKILL --kill-who=all "$app.service"
```

This treats `sumika-clipboard-store` (a stateful `wl-paste --watch` listener) the same
as `sumika-bar` (a UI shell).  Each stop kills the running `wl-paste --watch`; any
clipboard events that arrive during the stop–restart gap are lost.  Image copies
are especially vulnerable because `sumika-clipboard-store-event` retries the image read
up to 5 times—if the daemon is killed mid-retry, the image is never stored.

### 2. `start_app` launches even when already running

`bin/sumika-restart:209` calls `start_app` for every application module.  The daemon
already provides a `repair` subcommand that checks `is_running` and exits 0 if
the service is healthy.  Calling `start_app` unconditionally stop-starts the unit;
`repair` would be a no-op when the daemon is healthy.

### 3. Transient unit with `--collect` + SIGTERM → restart loop

`bin/sumika-restart:95` uses `systemd-run --user --unit=sumika-clipboard-store --collect`
with `Restart=on-failure`.  When reload stops the unit, systemd sends SIGTERM, which
exits with code 143.  This is classified as `Failed with result 'exit-code'`, which
triggers `Restart=on-failure` and immediately restarts the unit.  Combined with
`--collect` (unit definition vanishes after exit), this produces a repeating
stop–start ping-pong pattern (observed: 30-second cycles at 14:08–14:12 on
2026-07-25).

### 4. `sumika-restart` runs twice at login (second kill after first startup)

`hypr/autostart.lua` calls `o.exec_on_start(sumika-restart)`.  Journal shows the
restart scope running **twice** during login (~11 seconds apart on 2026-07-25
19:57:12 and 19:57:23).  The second invocation kills the daemon that the first
invocation just started, producing two spurious `types-unavailable` events in
the first minute.

## What has been fixed (non-reload, non-conflicting)

The only change was made in the extension's QML UI code,
`apps/sumika-clipboard/services/Cliphist.qml`:

- `filterEntries` now drops entries whose payload contains `__sumika_` (stale
  diagnostic probe strings left by earlier debugging sessions that were written
  to `wl-copy` and faithfully stored by the daemon).

## Mis-identified / non-issues

- **`ApplicationManager` does not call `start()` after `register()`:**  This is
  by design.  The QML-side `ApplicationManager` only handles IPC and manual
  launch; the real autostart path is `bin/sumika-restart` reading
  `entry.autostart` from the module registry.  Not a bug.

- **`types= ` (empty MIME list) in events.log:**  These are benign wake-ups that
  occur right after the daemon starts, before the Wayland clipboard owner has
  finished publishing its MIME types.  The event handler correctly ignores them.
  They were observed at 19:57:14 and 19:57:26 on 2026-07-25—immediately after
  the double-restart at login.

- **`__sumika_*` entries in cliphist list:**  Zero hits for these strings in
  production code.  They are remnants of earlier OMP/Codex debugging probes,
  not produced by any current component.

## Recommended fix (for the agent editing reload)

1. **`scripts/sumika-quickshell-stop.sh`**: Exclude `sumika-clipboard-store` (and any
   future stateful daemon) from the unconditional stop+kill loop.  The daemon
   has its own `stop` subcommand with proper PID-file and flock-based life-cycle.
   Alternatively, call `sumika-clipboard-store stop` (which uses `stop_existing`)
   instead of `systemctl stop` + SIGKILL.

2. **`bin/sumika-restart` `start_app`**: For modules whose entry command is a
   stateful daemon (detected by convention, or a manifest flag), call the
   module's `repair` subcommand instead of unconditional stop+start.
   `sumika-clipboard-store repair` already implements the correct "skip if running"
   behaviour.

3. **`bin/sumika-restart` `start_app` `systemd-run`**: Consider not using `--collect`
   for daemon-type units so the unit definition survives a transient exit and
   systemd's `Restart=on-failure` can work without the ping-pong effect.
