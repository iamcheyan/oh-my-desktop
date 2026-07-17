# Overview Search & Quick-Action: Disabled (Revert Guide)

As of this change, the Overview's search box and quick-action (session) menu
are **disabled** by user request. The Overview now behaves as a pure workspace
switcher: typing printable characters no longer opens search, and the search
field + `⋮` menu button are not rendered.

This is intentionally a reversible, comment-based disable — no logic was
deleted. To re-enable, uncomment the two blocks described below and restart
Quickshell (`~/.config/omd/bin/omd-restart`).

## What was disabled

### 1. `apps/omd-overview/modules/overview/OverviewSearch.qml`
The entire search-header (search field + menu button) and the session menu
block are wrapped in a `/* ... */` comment starting at the marker:

```
// ── Search box + quick-action button (disabled per request) ──
/*
MouseArea { ... }          // menuOpen click-catcher
Item { id: searchHeader }  // search field + menu button
Rectangle { id: sessionMenu }  // logout / restart / shutdown / reload shell
*/
```

The `root` properties (`query`, `searchMode`, `menuOpen`, `selectedIndex`,
signals `searchRequested`/`closeRequested`, and all functions) are **kept**
so `Overview.qml` bindings still resolve.

### 2. `apps/omd-overview/modules/overview/Overview.qml`
Inside `overviewKeyHandler`'s `Keys.onPressed`, the search-mode keyboard
handling is wrapped in a comment starting at the marker:

```
// ── Search mode keyboard handling (DISABLED: search UI removed) ──
/*
if (GlobalStates.overviewSearchMode) { ... }              // result nav + query edit
if (!GlobalStates.overviewSearchMode && printable) { ... } // enter search on type
*/
// Arrow keys navigate workspaces in workspace mode
if (!GlobalStates.overviewSearchMode) { handleOverviewNavigationKey(event); }
```

Kept active: `Esc` (closes overview), grabbed Win+Tab switching, and arrow-key
workspace navigation.

## How to revert

1. In `OverviewSearch.qml`, remove the `/*` and `*/` around the search-header /
   session-menu block (between the two markers above).
2. In `Overview.qml`, remove the `/*` and `*/` around the search-mode keyboard
   block.
3. Restart: `~/.config/omd/bin/omd-restart` (or `hyprctl reload` is not enough
   for Quickshell — use the restart script).

## Behavior after revert
- Open Overview, type any letter → search palette opens (apps + windows).
- `>` prefix → run a terminal command.
- `⋮` button → session menu (logout / restart / shutdown / reload shell).
