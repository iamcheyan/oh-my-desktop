# Overview Command Palette

The workspace Overview is Sumika Shell's primary navigation surface. Its command
palette keeps workspace navigation, application launching, window lookup, and
emergency terminal access in one keyboard-first entry point.

## Entry And Keyboard Model

- Open the normal Overview, then type any printable character to start search.
- Click the search field to enter search mode without an initial query.
- `Up` / `Down` or `Shift+Tab` / `Tab` changes the selected result.
- `Enter` activates the selected result.
- `Backspace` edits the query. `Esc` first exits search or closes the session
  menu, then closes Overview.
- Win+Tab grabbed switching mode is unchanged and does not show the palette.

The keyboard focus remains on `Overview.qml`. `OverviewSearch.qml` is a visual
and result-provider component; it deliberately does not create a `TextField`
or take layer-shell keyboard focus. This avoids the multi-monitor focus races
that affected the removed legacy search overlay.

## Providers

### Applications

`AppSearch.fuzzyQuery()` provides Desktop Entry results. Activating an app
focuses a new workspace on the Overview's anchor monitor, starts the app via
`AppSearch.launchApp()`, and closes Overview.

### Open Windows

Window title, initial title, class, initial class, workspace, and monitor are
searched from `HyprlandData.windowList`. Activating a result delegates to
`WorkspaceNavigation.focusWindow()` so MRU and Hyprland focus behavior remain
centralized.

### Terminal Commands

A query beginning with `>` is a terminal command:

```text
> hyprctl reload
> systemctl --user restart pipewire
> journalctl --user -f
```

The command opens in `xdg-terminal-exec --hold` through `bin/sumika-detach`.
Consequently the terminal is interactive, displays failures, survives the
Overview closing, and is not tied to the Overview process cgroup. Commands are
never inferred from ordinary search text; the `>` prefix is required.

## Session Menu

The button to the right of the search field contains:

- Log out
- Restart
- Shut down
- Reload Shell

The first three actions call the `session confirm` IPC exposed by
`apps/sumika-bar/shell.qml`. The bar process owns `SessionConfirmOverlay`, so all
entry points reuse the same confirmation and optional session-save behavior.
*Reload Shell calls `sumika-restart` directly after closing Overview.

## Files

- `quickshell/modules/overview/Overview.qml`: keyboard state and activation
- `quickshell/modules/overview/OverviewSearch.qml`: palette UI and providers
- `quickshell/services/AppSearch.qml`: application search and launch
- `quickshell/modules/common/functions/WorkspaceNavigation.qml`: window focus
- `apps/sumika-bar/shell.qml`: cross-process session confirmation IPC

## Extension Direction

Add future capabilities as providers rather than embedding feature-specific
logic in `Overview.qml`. Useful next providers are settings pages, clipboard
history, calculator/unit conversion, and common desktop actions. Prefixes
should be reserved for explicit modes (`>` commands, a future `=` calculator),
while ordinary text should continue to rank applications and open windows.
