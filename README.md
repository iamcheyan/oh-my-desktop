# oh-my-desktop

Personal Omarchy + Quickshell desktop configuration.

## Runtime Links

```sh
~/.config/quickshell -> ~/development/OMD/quickshell
~/.config/omarchy    -> ~/development/OMD/omarchy
```

Quickshell is launched from `~/.config/quickshell/scripts/quickshell` with the
flat config root `~/.config/quickshell`.

## Useful Commands

```sh
hyprctl reload
pkill -x quickshell; ~/.config/quickshell/scripts/quickshell &
```

## Current State

Branch `module-split` — single-repo modular configuration.

**Module manifests**: 14/14 v2 valid (all core modules). 0 v1 compat.

**All modules** live in `quickshell/modules/<id>/` — no external module repository.

**ServiceManager**: 10 providers (audio, network, power, workspace, brightness, notification, mpris, inputmethod, tray, bluetooth). All providers are QML singletons in Core process — NOT a full hot-pluggable provider architecture.

**Bar**: all widgets loaded via registry `ModuleLoader`, zero hardcoded feature branches.
