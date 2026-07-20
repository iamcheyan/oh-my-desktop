# Sumika Shell Migration Fixes: Round 3

Date: 2026-07-20

This round validates the first two migration reports against the executable
code and fixes the remaining path-contract and idempotency defects.

## Fixed

### QML state root duplicated the product suffix

`SUMIKA_SHELL_STATE_HOME` is already the canonical product directory, for
example `~/.local/state/sumika-shell`. Callers were appending another
`/sumika-shell`, producing a non-existent nested path.

`Directories.qml` now exposes two distinct properties:

- `stateHome`: raw XDG state root
- `sumikaStateHome`: canonical Sumika Shell state root

Wallpaper revision, theme, session snapshot, and Appearance page callers now
use `Directories.sumikaStateHome` directly.

### Re-running migration overwrote current data

The directory merge path used `cp -a`, which overwrote current Sumika Shell
files with stale legacy files on every run. Directory migration now uses a
no-clobber merge: existing destination data wins, while missing files are still
copied from the legacy tree.

### Config and state permissions were conflated

The migration created both trees with mode `0700`. This conflicted with the
chezmoi contract for normal configuration directories.

- `~/.config/sumika-shell`: directories normalized to `0755`
- `~/.local/state/sumika-shell`: directories normalized to `0700`

File modes are preserved, including executable user scripts.

### Runtime-only initialization skipped migration

`Init.sh --runtime-only` could replace runtime symlinks before migrating a
legacy real `~/.config/omd` directory. Full and runtime-only initialization now
call the same fatal `migrate_sumika_data` step before symlink repair.

### Hyprland toggles still loaded from legacy state

`hypr/default/hypr/toggles.lua` now loads from
`paths.state_home .. "/toggles/hypr"`, matching autostart and the shared Lua
path contract.

### Backup compatibility migration moved legacy data

`bin/omd-backup` retained a legacy fallback, but used `mv` when the canonical
directory was absent. That deleted the source before the explicit cleanup
phase. The fallback now copies without replacing an existing canonical tree,
keeps the legacy source, and normalizes config/state directory permissions.

## Verification

- `bash -n Init.sh`: pass
- `sh -n scripts/sumika-migrate.sh`: pass
- `luac -p` for the shared path and toggle modules: pass
- `git diff --check`: pass
- `bash -n bin/omd-backup`: pass
- Isolated first migration: pass
- Isolated second migration preserves newer theme/session files: pass
- Isolated second migration imports a missing legacy file: pass
- Dry-run creates no config or state tree: pass
- Resulting directory modes are config `0755`, state `0700`: pass

The isolated test uses a temporary HOME and does not read or alter the real
user configuration.
