# Session Persistence

OMD provides a small workspace snapshot tool for testing Hyprland session
restore behavior.

## Commands

```sh
omd-session status
omd-session save
omd-session save-auto
omd-session save-close
omd-session restore
omd-session restore-auto
omd-session clear
```

Snapshots are stored in:

```text
~/.local/state/omd/session/last.json
```

Automatic next-login restore is armed by:

```text
~/.local/state/omd/session/restore-on-next-start
```

`preview` returns a grouped snapshot without closing anything. The topbar uses
that command to show a confirmation popup before running `save-close`.

`save-close` saves the current Hyprland clients and then asks Hyprland to close
those saved windows. This is intentionally similar to a logout/shutdown test
flow, but it does not suspend or preserve application memory.

The long-term goal is a pseudo-hibernate: snapshot all windows before
shutdown/logout, then restore them after reboot so the desktop returns to its
previous state. Application memory, plain shell state, scrollback, and editor
buffers are never preserved by Hyprland itself. OMD restores window class,
workspace, geometry, launch command, terminal working directory, and attached
terminal multiplexer sessions when they can be detected.

## Topbar

The topbar has a workspace session icon through the `util:session` module.

- Non-empty desktop: the menu shows `Snapshot & Close Workspaces`, then opens a
  confirmation popup with workspace/window details.
- Saved snapshot: the menu shows `Restore Workspace Snapshot`.
- A saved snapshot can also be cleared from the menu.

## Logout / Shutdown Confirmation

Session-ending actions use the shared screen-centered confirmation overlay:

- `Logout`
- `Reboot`
- `Shutdown`

The overlay includes a checkbox:

```text
保存本次桌面会话，下次启动后自动恢复
```

When checked, OMD runs `omd-session save-auto` before the system action. This
saves the normal `last.json` snapshot and writes the `restore-on-next-start`
marker. The next time `omd-bar` starts, `SessionAutoRestore.qml` checks
`omd-session status`; if `autoRestore` is true, it shows the restore overlay and
runs `omd-session restore-auto`.

`restore-auto` consumes the marker before restoring so a normal Quickshell
reload does not repeatedly launch duplicate windows.

Empty snapshots are rejected. If `omd-session save`, `save-close`, or
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

For terminal windows, OMD reads the terminal process tree from `/proc`.

First it tries to detect a terminal multiplexer client:

- `tmux attach`, `tmux attach-session`, or `tmux a`
- `zellij attach`

When found, the snapshot stores the multiplexer type, session name, and command
prefix. On restore, OMD launches the original terminal and immediately attaches
back to the saved session, for example:

```text
alacritty --working-directory /repo -e zellij --config-dir ... attach tetsuya@asahi
kitty --directory /repo tmux attach-session -t Work
```

This preserves the terminal session only because tmux/zellij keep the session
alive after the terminal window closes.

If no multiplexer is detected, OMD falls back to the best working directory
and the foreground terminal program from the terminal process descendants.

When a non-shell child process is found, OMD stores its argv and cwd and
relaunches it inside the restored terminal. This is the fallback used for
plain `foot` and for kitty windows that were not opened with an OMD
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

If no foreground program is found, OMD passes only the cwd to supported
terminals:

- `foot --working-directory`
- `kitty --directory`
- `alacritty --working-directory`
- `ghostty --working-directory=`
- `wezterm start --cwd`

### Kitty Sessions

Kitty has its own startup session format. OMD supports it when the kitty window
was launched with a remote-control socket.

OMD's terminal launcher now starts kitty as:

```text
kitty --listen-on unix:$XDG_RUNTIME_DIR/omd-kitty-...sock --directory <cwd>
```

When `omd-session` sees that socket in `/proc/<kitty-pid>/cmdline`, it runs:

```text
kitty @ --to <socket> ls --output-format=session
```

The generated kitty session text is embedded in the OMD snapshot. During
restore, OMD writes it to:

```text
~/.local/state/omd/session/kitty/restore-<n>.session
```

and launches:

```text
kitty --session ~/.local/state/omd/session/kitty/restore-<n>.session
```

This can restore kitty tabs, windows, layouts, working directories, and the
commands recorded by kitty's session export. It still does not preserve Linux
process memory. If the original shell was running `nvim`, kitty can restart
`nvim` with the exported command, but unsaved editor memory belongs to nvim,
not kitty. For durable shell/editor state, use tmux/zellij or the application's
own session restore.

Existing kitty windows that were opened before this change do not have an OMD
remote-control socket, so OMD can only restore their working directory.

This is best-effort. Plain terminal shell state, scrollback, running foreground
programs, editor buffers, and application-internal state are not preserved
unless they already live inside tmux/zellij or the application has its own
session restore.

## Restore Behavior

Restore launches each saved command, waits for a matching Hyprland client by
class, then moves it back to the saved workspace. Floating windows also receive
their saved size and position.

After all windows are launched, OMD restores focus in a second pass:

1. Focus each saved monitor and switch it back to the workspace it displayed
   when the snapshot was taken.
2. Find the newly created window corresponding to the saved active window.
3. Focus that saved active window last.

This prevents the final restored application from stealing focus just because
it happened to launch last.

The first version intentionally does not try to rebuild Hyprland's exact tiling
tree. Tiled windows should return to their workspaces; exact split topology is
not guaranteed.
