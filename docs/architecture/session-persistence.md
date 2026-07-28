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

`preview` returns a grouped snapshot without closing anything. The topbar uses
that command to show a confirmation popup before running `save-close`.

`save-close` saves the current Hyprland clients and then asks Hyprland to close
those saved windows. This is intentionally similar to a logout/shutdown test
flow, but it does not suspend or preserve application memory.

The long-term goal is a pseudo-hibernate: snapshot all windows before
shutdown/logout, then restore them after reboot so the desktop returns to its
previous state. Application memory, plain shell state, scrollback, and editor
buffers are never preserved by Hyprland itself. Sumika Shell restores window class,
workspace, geometry, launch command, terminal working directory, and attached
terminal multiplexer sessions when they can be detected.

## Topbar

The topbar has a workspace session icon through the `util:session` module.

- Non-empty desktop: the menu shows `Snapshot & Close Workspaces`, then opens a
  confirmation popup with workspace/window details.
- Saved snapshot: the menu shows `Restore Workspace Snapshot`.
- A saved snapshot can also be cleared from the menu.

For the idle topbar icon state, `SessionButton.qml` reads `last.json` directly
with `FileView` instead of running `sumika-session status` during bar startup.
Preview, restore, and auto-restore still call `sumika-session` because those paths
need validation and Hyprland/process inspection.

## Logout / Shutdown Confirmation

Session-ending actions use the shared screen-centered confirmation overlay:

- `Logout`
- `Reboot`
- `Shutdown`

The overlay includes a checkbox:

```text
保存本次桌面会话，下次启动后自动恢复
```

When checked, Sumika Shell runs `sumika-session save-auto` before the system action. This
saves the normal `last.json` snapshot and writes the `restore-on-next-start`
marker. The next time `sumika-bar` starts, `SessionAutoRestore.qml` checks
`sumika-session status`; if `autoRestore` is true, it shows the restore overlay and
runs `sumika-session restore-auto`.

`restore-auto` consumes the marker before restoring so a normal Quickshell
reload does not repeatedly launch duplicate windows.

Empty snapshots are rejected. If `sumika-session save`, `save-close`, or
`save-auto` finds no mapped Hyprland clients, it prints a skipped result and
does not overwrite `last.json`. `save-auto` also removes any pending
`restore-on-next-start` marker so an empty logout cannot arm an invalid
automatic restore.

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
kitty --directory /repo tmux attach-session -t Work
```

This preserves the terminal session only because tmux/zellij keep the session
alive after the terminal window closes.

For tmux windows originally launched with `tmux new-session -A -s NAME`, Sumika Shell
preserves that attach-or-create form instead of reducing it to
`attach-session`. This distinction matters after a reboot: no tmux server
exists yet, so `new-session -A` starts one and allows `tmux-continuum` to load
the latest `tmux-resurrect` snapshot. Existing snapshots are also upgraded at
restore time from the raw Kitty remote-control JSON, so they do not need to be
saved again.

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
  session-format export drops.
- `kitty @ ls --output-format=session` — the kitty-native session file used
  for layout restore as a fallback.

#### Restore priority

If the kitty JSON reveals a running tmux/zellij client (via
`last_reported_cmdline`), Sumika Shell relaunches the multiplexer attach command
inside kitty, for example:

```text
kitty --directory "$HOME" tmux attach-session -t 0
```

This is preferred over the session-format file because the multiplexer
session survives the kitty window closing — attaching restores the real
shell session (windows, panes, scrollback, running programs), not just the
kitty layout.

If no multiplexer is detected, Sumika Shell writes the session-format text to:

```text
~/.local/state/sumika-shell/session/kitty/restore-<n>.session
```

and launches:

```text
kitty --session ~/.local/state/sumika-shell/session/kitty/restore-<n>.session
```

This restores kitty tabs, windows, layouts, and working directories. It does
not preserve Linux process memory or unsaved editor buffers. For durable
shell/editor state, use tmux/zellij or the application's own session restore.

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
