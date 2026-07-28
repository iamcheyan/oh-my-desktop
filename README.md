# Sumika Shell

Personal Omarchy + Quickshell desktop configuration.

## Runtime

```sh
~/.config/quickshell -> ~/development/OMD/quickshell
```

Quickshell is launched from `~/.config/quickshell/scripts/quickshell` with the
flat config root `~/.config/quickshell`. The session exports
`SUMIKA_SHELL_ROOT` for repository code and uses
`~/.config/sumika-shell` for user configuration.

## Useful Commands

```sh
sumika-restart
sumika-doctor
```

## Current State

Branch `module-split` — single-repo modular configuration.

All core module manifests use v2 and the `sumika-*` technical namespace.

Core modules live in `quickshell/modules/<id>/`. User extensions live under
`~/.local/share/sumika-shell/extensions/`.

**ServiceManager**: 10 providers (audio, network, power, workspace, brightness, notification, mpris, inputmethod, tray, bluetooth). All providers are QML singletons in Core process — NOT a full hot-pluggable provider architecture.

**Bar**: all widgets loaded via registry `ModuleLoader`, zero hardcoded feature branches.
