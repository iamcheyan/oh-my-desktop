# Keep Awake (long-task) mode

Keep the machine running with the lid closed so long-running background tasks
(SSH sessions, downloads, training runs) are never frozen by a suspend.

## How it works

`bin/sumika-keep-awake` registers a **block-mode** systemd inhibitor:

```
systemd-inhibit --what=handle-lid-switch:sleep --mode=block \
    --who=sumika-keep-awake --why="Keep Awake: lid-close suspend disabled" \
    sleep infinity
```

- `handle-lid-switch` — closing the lid no longer suspends the machine.
- `sleep` — any other suspend request (power key, manual Sleep button) is also
  blocked while the mode is on.
- `block` (not `delay`) — logind refuses the suspend outright instead of
  merely postponing it.

State is persisted in `$SUMIKA_SHELL_STATE_HOME/keep-awake{,.pid}`
(`~/.local/state/sumika-shell/keep-awake`). `hypr/autostart.lua` runs
`sumika-keep-awake ensure` at session start, so the mode survives reboots and
bar reloads while it is enabled.

## CLI

```
sumika-keep-awake on      # enable (idempotent)
sumika-keep-awake off     # disable, kill inhibitor
sumika-keep-awake status  # on|off (alive check, not just the state file)
sumika-keep-awake ensure  # re-assert persisted state (used at session start)
```

## UI

Power popup (bar → power indicator) has a **KEEP AWAKE** toggle below the
power profiles. It reads the state file via `FileView` and drives
`bin/sumika-keep-awake on|off`.

## Interaction with the rest of the system

- **Idle lock still applies.** After 152 s of no input the screen locks
  (hypridle → `sumika-lock`); the machine stays awake and tasks keep running.
- **The Sleep button in the power popup will not suspend** while Keep Awake is
  on — that is intentional (block-mode `sleep`).
- **Power draw**: with the lid closed the machine keeps running at full
  performance — expect battery drain and heat. The mode is designed for
  docked/plugged long-task scenarios.

## Verification

```
systemd-inhibit --list   # expect a sumika-keep-awake block entry
sumika-keep-awake status
```
