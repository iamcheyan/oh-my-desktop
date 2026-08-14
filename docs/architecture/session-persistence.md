# Session Persistence

Sumika Shell provides a small workspace snapshot tool for testing Hyprland session
restore behavior.

## Commands

```sh
sumika-session status
sumika-session save
sumika-session save-auto
sumika-session save-close
sumika-session restore
sumika-session restore-auto
sumika-session clear
```

Snapshots are stored in:

```text
~/.local/state/sumika-shell/session/last.json
```

Automatic next-login restore is armed by:

```text
~/.local/state/sumika-shell/session/restore-on-next-start
```

`preview` returns a grouped snapshot without closing anything. `save-close`
saves and then closes the saved windows; it is a CLI-only testing flow and is
not surfaced in the UI.

The long-term goal is a pseudo-hibernate: snapshot all windows before
shutdown/logout, then restore them after reboot so the desktop returns to its
previous state. Application memory, plain shell state, scrollback, and editor
buffers are never preserved by Hyprland itself. Sumika Shell restores window class,
workspace, geometry, launch command, terminal working directory, and attached
terminal multiplexer sessions when they can be detected.

## Shutdown Save Gate

Session-ending actions go through a screen-centered confirmation overlay with
a "Save current session" checkbox (default checked). The checkbox state is
recorded as a `save-requested` marker file before the system action runs.

The systemd fallback unit (`sumika-session-save.service` ExecStop) and the
logout script run `save-auto-if-stale` at session teardown. That command arms
`restore-on-next-start` only when the `save-requested` marker exists. Without
it, an empty or compositor-gone save unlinks the restore marker instead of
arming a stale restore, so an unchecked shutdown or an all-windows-closed
shutdown does not restore anything on the next login.

## Teardown Race (why a plain ExecStop snapshot is not enough)

Hyprland runs in a logind session scope, not a user unit. At shutdown,
logind kills the session scope — and with it the compositor — independently
of the user manager's unit teardown, so there is **no ordering guarantee**
between Hyprland dying and `sumika-session-save.service` ExecStop running.
When the compositor dies first, `hyprctl -j clients` exits 4. Historically
that exception crashed `save-auto-if-stale` after it had already consumed
the `save-requested` flag, leaving neither a fresh snapshot nor an armed
marker — the recurring "auto-restore didn't come back" bug. This also fires
on suspend/resume crashes (the compositor dies on resume before ExecStop).

Two mechanisms make the save path immune to this race:

1. **CompositorGone handling.** When Hyprland should be reachable but its
   IPC does not answer, `save-auto` arms `restore-on-next-start` whenever the
   rolling snapshot has real windows — regardless of the `save-requested`
   flag. CompositorGone is never a user opt-out (opt-outs go through the UI
   path while the compositor is alive and disarm via the empty-save branch);
   it is an unexpected death (suspend/resume crash, fast poweroff, Hyprland
   crash). The teardown save can no longer crash; worst case it restores a
   snapshot that is one rolling interval old.
2. **Rolling snapshots.** `sumika-session-rolling-save.timer` (5 min,
   graphical-session-scoped) runs `sumika-session save-rolling`, which
   writes `last.json` only when the restorable window set changed
   (fingerprint over class/workspace/geometry/launch command — never titles
   or `focusHistoryID`, which churn constantly). It never touches the marker
   and stays silent. It also skips while a restore is in progress (live
   restore-lock PID), so it never overwrites the snapshot being restored
   with a half-restored desktop. Result: `last.json` is at most ~5 minutes
   stale at any shutdown, whatever kills the compositor first.

When checked, Sumika Shell runs `sumika-session save-auto-if-stale` before the
system action. This saves `last.json` and writes the `restore-on-next-start`
marker (plus the `save-requested` flag). The next time `sumika-bar` starts,
`SessionAutoRestore.qml` checks `sumika-session status`; if `autoRestore` is
true, it shows the restore overlay and runs `sumika-session restore-auto`.

`restore-auto` consumes the marker before restoring so a normal Quickshell
reload does not repeatedly launch duplicate windows. `SessionAutoRestore`
ignores a marker whose `savedAt` is older than a week, so a stale marker
never restores a long-expired desktop. It does not check the current window
count: on a cold boot, autostart programs open windows before the bar's
startup delay elapses, which would falsely signal a non-empty desktop and
disarm the marker. The marker's own consume-on-restore semantics are
sufficient to prevent reload re-triggering.

Empty snapshots are rejected. If `sumika-session save`, `save-close`, or
`save-auto` finds no mapped Hyprland clients, it prints a skipped result and
does not overwrite `last.json`. When no save was requested, `save-auto`
removes any pending `restore-on-next-start` marker so an empty logout cannot
arm an invalid automatic restore.


## Captured State

The snapshot records every mapped client from `hyprctl -j clients`, including
clients on other monitors, inactive workspaces, and special workspaces:

- class and title (title used to disambiguate same-class windows)
- workspace and monitor (special workspaces included)
- floating state
- fullscreen state
- geometry for floating windows
- launch command inferred from `/proc/<pid>/cmdline`
- focus state:
  - active window address
  - active workspace
  - focused record (`focusHistoryID == 0` when available)
  - active workspace per monitor

For terminal windows, Sumika Shell reads the terminal process tree from `/proc`.

First it tries to detect a terminal multiplexer client:

- `tmux attach`, `tmux attach-session`, or `tmux a`
- `zellij attach`

When found, the snapshot stores the multiplexer type, session name, and command
prefix. On restore, Sumika Shell launches the original terminal and immediately attaches
back to the saved session, for example:

```text
alacritty --working-directory /repo -e zellij --config-dir ... attach tetsuya@asahi
foot --working-directory /repo tmux attach-session -t Work
```

Kitty windows restore differently: a kitty window with N panes can hold N
independent multiplexer sessions, so kitty always restores through a
synthesized session file that re-runs every pane's attach command (see
[Kitty Sessions](#kitty-sessions) below).

This preserves the terminal session only because tmux/zellij keep the session
alive after the terminal window closes.

For tmux windows originally launched with `tmux new-session -A -s NAME`, Sumika Shell
preserves that attach-or-create form instead of reducing it to
`attach-session`. This distinction matters after a reboot: no tmux server
exists yet, so `new-session -A` starts one and allows `tmux-continuum` to load
the latest `tmux-resurrect` snapshot. Existing kitty snapshots are re-pointed
at the session-file restore path at restore time, so they do not need to be
saved again — the file writer recovers each pane's attach command from the
captured JSON.

During restore, Sumika Shell associates each new window with the process PID started
for that specific snapshot record (including child processes) before moving
it to the saved workspace. Class and title matching are fallback mechanisms
only. This matters for multiple Kitty windows because their `initialTitle` is
usually the same generic `kitty` value; matching that field alone can place a
terminal on another terminal's workspace.

If no multiplexer is detected, Sumika Shell falls back to the best working directory
and the foreground terminal program from the terminal process descendants.

When a non-shell child process is found, Sumika Shell stores its argv and cwd and
relaunches it inside the restored terminal. This is the fallback used for
plain `foot` and for kitty windows that were not opened with an Sumika Shell
remote-control socket.

Examples:

```text
foot --working-directory /repo nvim CLAUDE.md
kitty --directory /repo ssh server-name
alacritty --working-directory /repo -e btop
```

This restarts the foreground program. It does not resurrect the original PID or
process memory. Unsaved editor buffers, REPL memory, and in-process state are
only preserved when the program itself has a session system or when it is
running inside tmux/zellij.

If no foreground program is found, Sumika Shell passes only the cwd to supported
terminals:

- `foot --working-directory`
- `kitty --directory`
- `alacritty --working-directory`
- `ghostty --working-directory=`
- `wezterm start --cwd`

### Kitty Sessions

Kitty has its own startup session format. Sumika Shell supports it when the kitty
window has a remote-control socket, which kitty creates either from a
`--listen-on` command-line flag or from the `listen_on` setting in
`kitty.conf`. Sumika Shell resolves the socket in three ways:

1. `--listen-on` in the kitty process argv (Sumika Shell-managed launches use this).
2. `KITTY_LISTEN_ON` in the environment of a kitty child window (set by kitty
   itself for `listen_on`-from-config instances; the socket path kitty uses
   is suffixed with the kitty PID, e.g. `unix:/tmp/mykitty-2885`).
3. Falls back to no kitty-session restore (cwd + program only).

When a socket is found, Sumika Shell captures both:

- `kitty @ ls` JSON — contains per-window `cmdline`, `last_reported_cmdline`,
  and `cwd`. This is what lets Sumika Shell detect a tmux/zellij multiplexer client
  running *inside* kitty (e.g. `tmux new-session -A -s 0`), which the
  session-format export drops. The JSON is captured **unfiltered** (no
  `--match pid:` filter): a filter would hide every pane but the first,
  collapsing a multi-pane window's multiple tmux/zellij sessions into one
  painting on restore.
- `kitty @ ls --output-format=session` — the kitty-native session file used
  for layout restore as a fallback.

#### Restore

A kitty window with N panes can hold N independent paintings (each pane
attached to its own tmux/zellij session). Restore therefore goes through a
synthesized session file that re-runs every pane's command, so each painting
reattaches to its own session:

1. Sumika Shell walks the captured JSON in tree order. For each pane it
   emits a `launch --cwd <dir>` directive running the pane's own command:
   a tmux/zellij attach for multiplexer panes (e.g. `launch --cwd $HOME
   tmux new-session -A -s Work`), or a replay of the pane's
   `last_reported_cmdline` through its shell for plain-command panes
   (`launch --cwd /tmp/x /usr/bin/zsh -c 'cd /tmp/x && dotnet run'; exec
   <shell>` keeps the pane alive after the command exits). Idle shells start
   a fresh interactive shell. `new_os_window`/`new_tab` markers preserve the
   original window/tab structure.
2. The result is written to:

   ```text
   ~/.local/state/sumika-shell/session/kitty/restore-<n>.session
   ```

   and every kitty window restores uniformly as:

   ```text
   kitty --session ~/.local/state/sumika-shell/session/kitty/restore-<n>.session
   ```

3. When the JSON panes carry no replayable command at all (idle shells with
   no `last_reported_cmdline`), the kitty-native layout dump is used
   unchanged — it restores tabs, windows, layouts, and working directories.
A bare `tmux new-session -A` without a session name cannot be restored
headlessly (tmux refuses to open a terminal), so such a pane degrades to a
plain shell. Old snapshots whose JSON was captured with a `--match` filter
hold only the first pane; if the layout dump lists more windows than the JSON
has, Sumika Shell uses the layout instead of synthesizing a one-pane file, so
the window structure survives even though the other panes' paintings are
unrecoverable from that snapshot.

This does not preserve Linux process memory or unsaved editor buffers. For
durable shell/editor state, use tmux/zellij or the application's own session
restore.

### Firefox Sessions

Firefox owns its tab and window session. A snapshot can contain several
Hyprland Firefox windows, but Sumika Shell must not start Firefox once for every saved
window. The first launch restores Firefox's complete native session; additional
launch requests create extra homepage windows and duplicate the restored
browser state.

During restore, Sumika Shell therefore:

1. starts Firefox exactly once through its normal distribution/user launcher,
   or reuses it if it is already running;
2. uses the current Wayland/GDK scaling environment, falling back to saved
   values only when cold-start variables are missing, and waits for Firefox to
   recreate all expected windows (without an early three-second cutoff);
3. matches recreated windows to saved records by title;
4. moves each matched window back to its saved Hyprland workspace.

Hyprland reports Firefox's final internal executable (for example
`/usr/lib64/firefox/firefox`). Sumika Shell deliberately does not relaunch that path:
it bypasses the distribution wrapper's remoting setup and can start with a
different scale from a normal desktop launch. New snapshots store only a
small, non-sensitive graphics-environment allowlist. Sumika Shell does not synthesize
an inverse `GDK_DPI_SCALE`: Firefox already consumes `GDK_SCALE`, and applying
the inverse makes restored windows abnormally small. A saved
`GDK_DPI_SCALE` is also ignored so snapshots created by the older behavior do
not carry the bad scale into later sessions; only an explicit value from the
current desktop environment is respected.

Firefox should keep `browser.startup.page` set to `3` (restore previous windows
and tabs). The homepage preference is only a fallback when Firefox has no
restorable native session; it is not used by Sumika Shell to reconstruct tabs.

## Restore Behavior

Restore launches each saved command, waits for a matching Hyprland client by
class, then moves it back to the saved workspace. Firefox is handled as the
single-launch application-owned session described above. Floating windows also
receive their saved size and position.

After all windows are launched, Sumika Shell restores focus in a second pass:

1. Focus each saved monitor and switch it back to the workspace it displayed
   when the snapshot was taken.
2. Find the newly created window corresponding to the saved active window.
3. Focus that saved active window last.

This prevents the final restored application from stealing focus just because
it happened to launch last.

The first version intentionally does not try to rebuild Hyprland's exact tiling
tree. Tiled windows should return to their workspaces; exact split topology is
not guaranteed.
