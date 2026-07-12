# Quickshell Cold-Start Recovery Notes

## Current Incident

After the split-app and cold-start refactor, the desktop could reach a state
where Hyprland started but Quickshell did not show the bar, overview, or
settings center. Running `bash scripts/reload-quickshell` could appear to help
partially, but several modules still failed:

- `omd-bar` loaded and then crashed.
- `omd-overview` loaded and then exited, so `qs -p ... ipc call overview open`
  returned `No running instances`.
- `omd-settings` loaded and then exited, so settings opened from bar buttons
  immediately disappeared.

The user-visible symptom was inconsistent because reload starts multiple split
apps and some helper processes (`wl-paste`, wallpaper, etc.) can remain alive
even when the Quickshell UI processes crash.

## Root Cause

The hard crash was caused by runtime audio device state stored inside
`quickshell/config.json`:

```json
{
  "audio": {
    "levels": {
      "alsa_output...": {
        "volume": 0.53,
        "muted": false
      }
    }
  }
}
```

`Config.qml` reads `config.json` through Quickshell's `JsonAdapter`. On the
current Quickshell build, deserializing this dynamic nested object into the
`audio.levels` `property var` can segfault inside
`JsonAdapter.deserializeAdapter`. That crash happens before the app can recover,
so all split apps that import the shared `Config` singleton are affected.

The important rule is:

> `quickshell/config.json` is for stable user settings, not high-churn runtime
> maps keyed by hardware IDs or process IDs.

Runtime state must live under XDG state/cache paths and be parsed manually when
the schema is dynamic.

## Fix Strategy

The fix is intentionally conservative:

1. Keep stable audio settings in `config.json`, for example
   `audio.protection.enable`.
2. Move per-device audio volume/mute state out of `config.json` and into:

   ```text
   $XDG_STATE_HOME/quickshell/audio-levels.json
   ```

   via `Directories.state`.
3. Remove `audio.levels` from `Config.qml` and add a startup repair step in
   `quickshell/scripts/quickshell` that deletes stale `audio.levels` before
   launching any split app.
4. Add the same repair to `Init.sh`, so deploy/update also cleans old configs.
5. Keep `omd-overview` and `omd-settings` with stable top-level windows. Cold
   app content can be hidden, but the process must not start with no viable
   top-level shell object.

For existing machines that already have dependencies installed, run:

```sh
./Init.sh --runtime-only
```

This repairs runtime symlinks and removes stale runtime-only config fields
without reinstalling packages or writing system session files.

## Cold-Start Rules

Long-lived modules:

- `omd-bar`
- `omd-overview`
- `omd-polkit`
- `omd-clipboard-store`

These must survive login without user interaction. Do not wrap their only
top-level UI in a `LazyLoader` gated by `Config.ready`; Quickshell may exit
before the loader creates a window.

On-demand modules:

- `omd-settings`
- `omd-applauncher`
- `omd-clipboard`
- `omd-screenshot`

These may quit after the dialog closes, but their launchers must:

- set the needed `OMD_*_ON_DEMAND` env var,
- set `QS_CONFIG_DIR`, `OMD_APP_DIR`, and Wayland/Hyprland env vars,
- launch with `qs -p <app_dir>` or the repo wrapper consistently,
- provide a top-level window while the app is open.

## Diagnostics

Useful checks:

```sh
bash scripts/reload-quickshell
pgrep -af '(quickshell|qs).*omd-|wl-paste'
systemctl --user status omd-bar.service omd-overview.service --no-pager -l
qs -p ~/.config/omd/apps/omd-overview ipc call overview open
bin/omd-settings open display
journalctl --user -u omd-bar.service -n 120 --no-pager
```

If a Quickshell process logs `Configuration Loaded` and then disappears, check
systemd for `code=dumped, signal=SEGV`. If the stack mentions
`JsonAdapter.deserializeAdapter`, inspect `quickshell/config.json` first.

## Do Not Reintroduce

- Do not store PipeWire node maps, clipboard entries, notification history,
  workspace snapshots, or other dynamic runtime maps in `config.json`.
- Do not use `Config.setNestedValue()` for high-churn runtime state.
- Do not make a split app's only top-level `PanelWindow` depend on
  `Config.ready`.
- Do not send new settings-center requests to the old bar dialog IPC.
