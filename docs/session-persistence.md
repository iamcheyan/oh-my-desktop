# Session Persistence

OMD provides a small workspace snapshot tool for testing Hyprland session
restore behavior.

## Commands

```sh
omd-session status
omd-session save
omd-session save-close
omd-session restore
omd-session clear
```

Snapshots are stored in:

```text
~/.local/state/omd/session/last.json
```

`save-close` saves the current Hyprland clients and then asks Hyprland to close
those saved windows. This is intentionally similar to a logout/shutdown test
flow, but it does not suspend or preserve application memory.

The long-term goal is a pseudo-hibernate: snapshot all windows before
shutdown/logout, then restore them after reboot so the desktop returns to its
previous state. Application memory, shell state, scrollback, and editor
buffers are never preserved — only window class, workspace, geometry, and
(for terminals) the working directory are restored.

## Topbar

The topbar has a workspace session icon through the `util:session` module.

- No saved snapshot: the menu shows `Save & Close Workspaces`.
- Saved snapshot: the menu shows `Restore Workspace Snapshot`.
- A saved snapshot can also be cleared from the menu.

## Captured State

The snapshot records data from `hyprctl -j clients`, including:

- class and title (title used to disambiguate same-class windows)
- workspace and monitor (special workspaces included)
- floating state
- fullscreen state
- geometry for floating windows
- launch command inferred from `/proc/<pid>/cmdline`

For terminal windows, OMD tries to read the best working directory from the
terminal process and its descendants. On restore it passes the cwd to supported
terminals:

- `foot --working-directory`
- `kitty --directory`
- `alacritty --working-directory`
- `ghostty --working-directory=`
- `wezterm start --cwd`

This is best-effort. Terminal shell state, scrollback, running foreground
programs, editor buffers, and application-internal state are not preserved.

## Restore Behavior

Restore launches each saved command, waits for a matching Hyprland client by
class, then moves it back to the saved workspace. Floating windows also receive
their saved size and position.

The first version intentionally does not try to rebuild Hyprland's exact tiling
tree. Tiled windows should return to their workspaces; exact split topology is
not guaranteed.
