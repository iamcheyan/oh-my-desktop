# Lock screen & the "Oopsie daisy" crash

Sumika's screen lock is the Quickshell `WlSessionLock` component, which lives
**inside the bar's Quickshell process** (`apps/sumika-bar`). It is not a
separate `hyprlock`/`swaylock` process. The standalone `hyprlock` was removed
in commit `12caf6d`; `WlSessionLock` replaced it.

## How the lock engages

`GlobalStates.screenLocked` flips to `true` → the `WlSessionLock` object in
`LockScreen.qml` activates the ext-session-lock-v1 protocol and shows the lock
surface. Flip it back to `false` (correct password) to unlock.

Trigger paths that set `screenLocked = true`:

| Path | Entry point |
|---|---|
| Idle timeout (hypridle, 152 s) | `hypr/hypridle.conf` `on-timeout = sumika-lock` |
| Suspend / resume | hypridle `before_sleep_cmd = sumika-lock` |
| Keybind `SUPER + CTRL + L` | `hypr/default/hypr/bindings/utilities.lua` → `sumika-action session.lock` |
| Power popup "Lock" button | `PowerPopup.qml` → `session.lock` action |
| GlobalShortcut `lock` / IPC `lock activate` | `LockScreen.qml` |

All converge on `LockService.lock()` → `LockScreen.lock()` →
`lockContext.lockWithCapture()`. `sumika-lock` (shell) just IPCs `lock
activate` into the bar.

## The crash: "Oopsie daisy"

Hyprland's ext-session-lock-v1 safety guarantee: once a lock is requested, the
outputs stay blocked until a locker provides lock surfaces. **If the locker
client dies while locked, Hyprland falls back to the white "Oopsie daisy"
recovery screen** and refuses to unlock (security).

Because the locker IS the bar process, **anyone who kills the bar while the
screen is locked triggers the crash screen.** This is the only known cause.
The lock component itself is stable; every recorded "Oopsie daisy" was a bar
kill while locked (most recently: `systemctl --user restart sumika-bar.service`
run during development while the 152 s idle lock had engaged).

## Prevention — the `sumika-restart` lock guard

`bin/sumika-restart` is the ONLY sanctioned way to reload the bar. Before
killing any Quickshell process it asks the live bar `ipc call lock active` and
is **fail-closed**:

| Bar state | Decision |
|---|---|
| `lock active` = `false` | proceed (safe) |
| `lock active` = `true` | **refuse** — "Screen is locked" |
| IPC empty + bar process alive | **refuse** — bar hung, may be mid-lock |
| IPC empty + bar process gone | proceed — bar crashed, any lock died with it |

Override with `sumika-restart --force` only when you are certain the screen is
not locked (e.g. the bar is merely stuck and you can see the unlocked desktop).

### Hard rule

**NEVER use `systemctl --user restart sumika-bar.service` (or `stop`, or
`pkill -f quickshell`) to reload the bar.** These bypass the guard and kill the
bar unconditionally — if the idle lock is engaged, you get "Oopsie daisy".
Always use `sumika-restart`. This applies to development, debugging, and any
automation.

The systemd unit's `Restart=on-failure` is safe: it only fires after a real
crash, by which point any lock already died with the bar (the crash screen, if
any, has already happened) — restarting cannot make it worse.

## Recovery if you are already on "Oopsie daisy"

You are on a tty with the white recovery screen. The compositor is waiting for
a locker to take over the dead lock.

1. Switch to a free tty (e.g. `Ctrl+Alt+F3`) and log in.
2. Allow a new locker to restore the session:
   ```
   hyprctl eval 'hl.config({ misc = { allow_session_lock_restore = true } })'
   ```
   (`hyprctl keyword` does not work on the Lua config parser in 0.55.x; use
   `hyprctl eval` with the `hl.config` form.)
3. Launch a locker to satisfy the protocol — `swaylock` is shipped for this:
   ```
   swaylock -d
   ```
   (Hyprland's own lock screen cannot take over a dead lock; an external
   locker is the one-time recovery tool.)
4. Enter your user password to unlock. swaylock exits, the session is restored.
5. Optionally reset the restore flag for hygiene:
   ```
   hyprctl eval 'hl.config({ misc = { allow_session_lock_restore = false } })'
   ```

The recovery locker (swaylock) is NOT the daily driver — after unlocking, idle
will re-engage the Quickshell `WlSessionLock` as normal. swaylock is only the
emergency takeover tool.

## Disabling the lock (not recommended)

The lock is enabled and expected to work. If a real `WlSessionLock` crash bug
ever appears (crash on idle with no bar kill involved), the clean temporary
disable is: remove the `listener { on-timeout = sumika-lock }` block from
`hypr/hypridle.conf` and no-op `LockService.lock()` / `LockScreen.lock()`. Do
not do this speculatively — every incident so far was a bar kill, not a lock
bug.