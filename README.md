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

Branch `module-split` — ongoing Core/Plugin modularization migration.

**Module manifests**: 27/27 v2 valid (18 OMD modules + 9 external). 0 v1 compat.

**Active-window**: migrated from external `sumika-modules` to OMD `modules/active-window`.

**4 external modules**: upgraded to v2 schema (brightness-gamma, keyboard-remap, popup-components, voice).

**ServiceManager**: 10 providers (audio, network, power, workspace, brightness, notification, mpris, inputmethod, tray, bluetooth). All providers are QML singletons in Core process — NOT a full hot-pluggable provider architecture.

**Bar**: all widgets loaded via registry `ModuleLoader`, zero hardcoded feature branches.
