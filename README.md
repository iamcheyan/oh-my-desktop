# Sumika Shell

Personal Omarchy + Quickshell desktop configuration.

## Install

```sh
git clone git@github.com:iamcheyan/oh-my-desktop.git ~/development/OMD
cd ~/development/OMD
./Init.sh
```

The installer sets up the Core desktop only. Optional extensions are discovered
from `~/.local/share/sumika-shell/extensions/` and manage their own
dependencies; installing an extension does not expand the Core package set.
See [Core dependencies](docs/architecture/third-party-deps.md).

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

**ServiceManager**: Core providers cover audio, network, power, workspaces,
brightness, notifications, MPRIS, tray, and Bluetooth. Extension-local
services remain inside their extension.

**Bar**: all widgets loaded via registry `ModuleLoader`, zero hardcoded feature branches.
