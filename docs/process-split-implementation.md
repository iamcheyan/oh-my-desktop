# OMD Process Split Implementation

This document records the concrete process split used during the first
multi-process migration.

## Current Goal

Separate the bar from workspace overview/switcher failures.

The first process boundary is:

```text
omd-bar       persistent bar and bar-adjacent UI
omd-overview  overview/switcher visual surface
omd-switcher  lightweight Win+Tab shortcut and IPC relay
```

`omd-switcher` currently delegates display to `omd-overview`. This keeps the
first split small while still moving Win+Tab dispatch out of `omd-bar`.

## Runtime Paths

Runtime uses:

```text
~/.config/omd -> ~/development/OMD
```

App roots:

```text
~/.config/omd/apps/omd-bar
~/.config/omd/apps/omd-overview
~/.config/omd/apps/omd-switcher
```

Launchers:

```text
~/.config/omd/bin/omd-bar
~/.config/omd/bin/omd-overview
~/.config/omd/bin/omd-switcher
~/.config/omd/bin/omd-restart
```

Each app launches through:

```sh
quickshell/scripts/quickshell <app-root>
```

## App Ownership

### `omd-bar`

Owns:

- top bar
- bar dialog overlay
- right sidebar
- schedule popup
- app launcher
- notification popup
- OSD
- screen corner chrome and hot corners
- polkit UI

The Workspaces button and top-left hot corner no longer mutate local
`GlobalStates.overviewOpen`. They call the `omd-overview` process over
Quickshell IPC.

### `omd-overview`

Owns:

- overview panel windows
- current overview UI
- current Win+Tab visual surface
- shared workspace/window navigation rules

The process exposes IPC targets:

```text
overview.toggle/open/close
switcher.next/prev/commit
```

### `omd-switcher`

Owns:

- `switcherNext`
- `switcherPrev`
- `switcherCommit`

For now these shortcuts relay to `omd-overview`:

```sh
qs -p ~/.config/omd/apps/omd-overview ipc call switcher next
```

Later this process can render its own lightweight switcher UI while continuing
to use `WorkspaceNavigation`.

## Shared Code

The first split reuses the existing source tree through symlinks inside each
app root:

```text
modules      -> ../../quickshell/modules
services     -> ../../quickshell/services
assets       -> ../../quickshell/assets
scripts      -> ../../quickshell/scripts
translations -> ../../quickshell/translations
config.json  -> ../../quickshell/config.json
GlobalStates.qml -> ../../quickshell/GlobalStates.qml
ReloadPopup.qml  -> ../../quickshell/ReloadPopup.qml
```

This gives process isolation before the source tree is fully rearranged into
`common/` and app packages.

## Verification

After changes:

```sh
sh -n quickshell/scripts/quickshell
python -m json.tool quickshell/config.json >/tmp/omd-config-check.json
luac -p omarchy/hypr/bindings.lua
hyprctl reload
~/.config/omd/bin/omd-restart
pgrep -af 'quickshell|qs -p'
hyprctl binds | rg 'Quickshell (bar|overview|switcher)'
```

Expected processes:

```text
quickshell -p $HOME/.config/omd/apps/omd-bar
quickshell -p $HOME/.config/omd/apps/omd-overview
quickshell -p $HOME/.config/omd/apps/omd-switcher
```
