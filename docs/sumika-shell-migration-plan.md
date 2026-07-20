# Sumika Shell rename and user configuration migration plan

## Objective

Rename the project to **Sumika Shell** and remove machine-specific/user-owned
configuration from the Git repository without breaking the current desktop.

The first functional milestone is deliberately narrow:

1. The public project name becomes Sumika Shell.
2. User-authored configuration moves to `~/.config/sumika-shell/`.
3. Generated/runtime state moves to `~/.local/state/sumika-shell/` where
   appropriate.
4. The repository remains the code and asset source.
5. Existing `omd-*` commands and `org.omd.*` application IDs remain compatible
   until a later rename phase.

Do not combine the initial configuration migration with a mass rename of every
binary, IPC target, systemd unit, QML import, app ID, or Hyprland rule.

## Non-negotiable invariants

- The active desktop must remain usable after every commit.
- Never delete or overwrite user data before a verified copy exists.
- `Init.sh` must be idempotent and safe to run repeatedly.
- The project must work without chezmoi. Chezmoi integration is optional.
- Do not hard-code `~/development/OMD` or `~/development/sumika-shell` in
  runtime code.
- Do not use `~/.config/sumika-shell` as a source-code discovery path.
- Keep a compatibility reader for the old `~/.config/omd` locations during
  the migration.
- Do not rename `omd-*`, `org.omd.*`, IPC targets, or systemd units in the
  first milestone.
- Do not commit copied wallpapers, generated themes, private paths, device
  identifiers, notification mute history, or personal launchers.

## Path contract

All components must use the same path contract:

| Variable | Default | Ownership |
|---|---|---|
| `SUMIKA_SHELL_ROOT` | resolved repository root | code and bundled assets |
| `SUMIKA_SHELL_CONFIG_HOME` | `${XDG_CONFIG_HOME:-~/.config}/sumika-shell` | durable user-authored configuration |
| `SUMIKA_SHELL_STATE_HOME` | `${XDG_STATE_HOME:-~/.local/state}/sumika-shell` | generated and machine-local state |
| `SUMIKA_SHELL_DATA_HOME` | `${XDG_DATA_HOME:-~/.local/share}/sumika-shell` | installed/shared data, if needed later |
| `SUMIKA_SHELL_RUNTIME_DIR` | `${XDG_RUNTIME_DIR}/sumika-shell` | sockets, locks, transient files |

During compatibility mode, export:

```sh
OMD_ROOT="$SUMIKA_SHELL_ROOT"
```

Existing code can continue using `OMD_ROOT` while new code uses the Sumika
Shell variables. `OMD_ROOT` must continue to mean **repository root**, never
the user configuration directory.

## Data classification and target mapping

### User-authored configuration

Move these to `~/.config/sumika-shell/`:

| Current path | New path | Notes |
|---|---|---|
| `keyboard-remap/profiles.json` | `keyboard-remap/profiles.json` | preserve user profiles |
| `notifications/muted_apps.cfg` | `notifications/muted_apps.cfg` | create an empty file for new installs |
| `file-share-backup/config.json` | `file-share-backup/config.json` | private; never commit or automatically add to chezmoi |
| personal `launchers/*.desktop` | `launchers/*.desktop` | source definitions only |
| personal launcher icons | `launchers/icons/` | private/user-owned assets |
| user Quickshell overrides | `quickshell/config.json` | split from repository defaults before moving |

Desktop launchers that should appear in application menus must be installed or
linked into `${XDG_DATA_HOME:-~/.local/share}/applications/`. Merely storing a
desktop file under `~/.config/sumika-shell/launchers` does not register it.

### Generated and machine-local state

Do not place these in the configuration directory or chezmoi:

| Current path | New state path |
|---|---|
| `current/theme.name` | `theme/current-name` |
| `current/theme/` | `theme/current/` |
| `current/background` | `wallpaper/current` |
| `current/wallpaper` | `wallpaper/current-file` or a symlink to the selected file |
| `current/wallpaper.revision` | `wallpaper/revision` |
| `keyboard-remap/keyd.generated.conf` | `keyboard-remap/keyd.generated.conf` |
| display layout | `display/` |
| session snapshots | `session/` |
| wallpaper rotation mode/index/interval | `wallpaper/` |

Bundled theme templates stay in `share/themes/` in the repository. Selecting a
theme copies or generates the active files into the state directory.

### Repository defaults

Replace personal tracked files with neutral defaults:

```text
defaults/
  config/
    keyboard-remap/profiles.json
    notifications/muted_apps.cfg
    quickshell/config.json
```

Defaults must not contain the current developer's devices, launchers, paths,
muted applications, wallpaper, or selected theme.

## Configuration loading model

Do not keep one writable `quickshell/config.json` inside the repository.

Use two layers:

1. Repository defaults: `defaults/config/quickshell/config.json`
2. User overrides: `~/.config/sumika-shell/quickshell/config.json`

At launch, generate a merged runtime file under:

```text
~/.local/state/sumika-shell/quickshell/config.json
```

Merge objects recursively, with user values overriding defaults. Arrays replace
the default array unless a feature explicitly defines another policy. Validate
the merged JSON before starting Quickshell. If the user file is malformed, keep
the last known-good generated file and report the error instead of preventing
the bar from starting.

Quickshell processes should receive the generated config path through one
shared launcher/environment mechanism. Feature QML must not reconstruct these
paths independently.

## Repository root discovery

The session must be able to start after `~/.config/omd` stops pointing at the
repository.

Use this order:

1. `SUMIKA_SHELL_ROOT`, if set and valid.
2. Resolve the repository from the invoked launcher using `readlink -f` and
   `dirname`.
3. Read a generated root locator written by `Init.sh`, for example
   `~/.config/sumika-shell/source-root`.
4. During migration only, accept the old `OMD_ROOT` or resolved
   `~/.config/omd` symlink.

`Init.sh` must write the actual absolute repository path into the installed
Hyprland session wrapper. Moving the repository requires rerunning `Init.sh`.
Do not put `$HOME/development/...` assumptions in QML, Lua, or shell scripts.

## Execution plan

Each numbered step is a separate commit unless explicitly noted.

### 0. Repair and capture the baseline

Before migration:

- Restore the accidentally removed `create_symlinks() {` declaration in
  `Init.sh`.
- Make `bash -n Init.sh` pass.
- Update `omd-doctor` so it no longer expects repository-managed terminal
  config symlinks.
- Record current symlink targets with `readlink -f`.
- Back up user-owned files to a timestamped directory outside the repository.
- Run the current smoke-test checklist and record the result.

Suggested commit:

```text
fix(init): restore valid setup baseline before config migration
```

Stop if the existing desktop cannot pass the baseline tests.

### 1. Introduce the path API without moving files

Add one shell path helper and equivalent Lua/QML accessors. They expose the
Sumika Shell path contract but initially support old paths as fallback.

Required behavior:

- Every `bin/omd-*` launcher exports the path contract before launching QML.
- Every split Quickshell process inherits the same variables.
- Hyprland `paths.lua` exposes separate `root`, `config_home`, `state_home`,
  `data_home`, and `runtime_dir` fields.
- No feature module builds `~/.config/omd` or `~/.config/sumika-shell` with
  string concatenation.

Suggested commit:

```text
refactor(paths): add Sumika Shell code config and state roots
```

### 2. Make the session independent of `~/.config/omd`

- Generate the Hyprland session wrapper with the real repository path.
- Change `hypr/autostart.lua` to launch through the exported root or commands
  found on `PATH`.
- Ensure `omd-restart`, all split Quickshell launchers, wallpaper restore, and
  polkit start without the repository symlink.
- Temporarily rename `~/.config/omd` during testing to prove source discovery
  no longer depends on it, then restore it.

Suggested commit:

```text
refactor(session): decouple runtime startup from config omd symlink
```

Do not proceed until a fresh login works with the old symlink temporarily
absent.

### 3. Create the migration utility

Implement an idempotent migration command invoked by `Init.sh`.

It must:

1. Detect whether `~/.config/omd` is a symlink, directory, or absent.
2. Resolve and copy old data before unlinking anything.
3. Create `~/.config/sumika-shell` and `~/.local/state/sumika-shell` with mode
   `0700` where private data may exist.
4. Copy each known file only when its destination is absent.
5. Never overwrite a newer destination silently.
6. Use temporary files plus atomic rename.
7. Write a migration version marker and log.
8. Support `--dry-run` and print every planned operation.
9. Leave the source data intact until final cleanup.

Do not write backups into a fixed `~/chezmoi` path. Use a timestamped backup
under `~/.local/state/sumika-shell/migration-backups/`, and optionally explain
how users can add selected config files to chezmoi afterward.

Suggested commit:

```text
feat(migration): add idempotent Sumika Shell config migrator
```

### 4. Migrate individual configuration domains

Move and test one domain per commit:

1. Notification muted-app configuration.
2. Keyboard remap profiles and generated keyd state.
3. File-share/backup configuration and state.
4. Personal launcher definitions and XDG application installation.
5. Quickshell defaults, user overrides, and merged runtime config.

Every reader and writer must use the path API. During this phase, reads may
fall back to the old location, but all new writes go only to the new location.

Example commit names:

```text
refactor(notifications): move muted apps to Sumika config
refactor(keyboard): separate remap profiles from generated state
refactor(backup): move private backup config outside repository
refactor(launchers): install user launchers from Sumika config
refactor(quickshell): split defaults overrides and generated config
```

### 5. Migrate generated theme and wallpaper state

This is separate from user configuration because it has a wider blast radius.

- Keep templates in `share/themes/`.
- Move active generated theme files to the state directory.
- Move wallpaper current target, revision, rotation mode, index, and interval
  to the state directory.
- Update Hyprland theme loading, QML theme loading, clipboard styling,
  terminal theme helper paths, overview wallpaper previews, swaybg restore,
  and theme reload IPC together.
- Seed a state file only when none exists. Do not reintroduce a tracked default
  wallpaper that flashes before the selected wallpaper.

Suggested commit:

```text
refactor(theme): move active theme and wallpaper into Sumika state
```

### 6. Remove the repository symlink

Only after all previous acceptance tests pass:

- Stop creating `~/.config/omd -> repo`.
- Create `~/.config/sumika-shell` as a real directory.
- Keep a temporary compatibility symlink or tiny compatibility directory only
  if an external integration still requires it. It must point to configuration,
  never to the repository.
- Update doctor to fail on new source-code references through
  `~/.config/omd`.

Add a CI/local check such as:

```sh
rg '~/.config/omd|\.config/omd|Directories\.config.*omd' \
  bin scripts share hypr quickshell apps
```

Any remaining match must be an explicitly documented migration fallback.

Suggested commit:

```text
refactor(config): replace repository symlink with Sumika config directory
```

### 7. Remove personal and generated files from Git

After proving the migrated destinations contain the required data:

- Remove tracked `current/` generated snapshots.
- Remove tracked keyboard profiles/generated output and replace profiles with a
  neutral default under `defaults/`.
- Remove personal launcher files and icons.
- Remove tracked notification mute history.
- Ensure private backup files remain ignored.
- Add ignore rules for generated state only if any state can still appear in
  the repository during compatibility mode.

Suggested commit:

```text
chore(repo): remove personal configuration and generated runtime state
```

### 8. Apply the public Sumika Shell name

The README, documentation, window titles, About page, logo text, and repository
metadata may now use **Sumika Shell**. The GitHub repository and local checkout
directory can be renamed here. Rerun `Init.sh` after moving the checkout.

Keep these technical names temporarily:

- `omd-*` commands
- `org.omd.*` app IDs/classes
- existing IPC target names
- existing systemd unit names
- `OMD_ROOT` compatibility environment variable

Suggested commit:

```text
chore(branding): rename project to Sumika Shell
```

### 9. Optional internal identifier rename

Perform this only as a separate project after the configuration migration is
stable. Introduce `sumika-*` commands as canonical names and retain `omd-*`
wrapper aliases for at least one release. Rename app IDs, window rules, IPC
targets, polkit rules, service names, and logs in coordinated batches.

## Acceptance test matrix

Run after every relevant phase.

### Static validation

```sh
bash -n Init.sh
find bin scripts share/bin -type f -perm -u+x -exec bash -n {} \;  # shell files only
hyprctl configerrors
~/.config/omd/bin/omd-doctor   # compatibility phase
```

Use the repository launcher path after the compatibility symlink is removed.

### Cold-start validation

1. Stop all Sumika/OMD Quickshell processes.
2. Start the session through the installed session wrapper.
3. Confirm bar, overview, clipboard store, polkit, wallpaper, and notifications.
4. Log out and back in once; do not rely only on hot reload.

### Feature validation

- Bar loads and every popup opens.
- Overview opens from Super and Win+Tab; previews show the current wallpaper.
- App launcher and clipboard open repeatedly after cold start.
- Text, image-as-path, and voice paste each insert exactly once.
- Notification popups and notification history work; muted apps persist.
- Keyboard profiles persist and keyd generated config applies.
- Theme switching updates Hyprland, Quickshell, supported terminals, and Neovim.
- Single wallpaper and folder rotation survive restart without black/default
  flashes.
- Display settings and session snapshot save/restore still work.
- File-share/backup settings retain private configuration.
- Personal launchers remain discoverable through XDG application search.

### Migration validation

- Run migration twice and verify the second run makes no changes.
- Test with old `~/.config/omd` as a symlink.
- Test with it as a real directory.
- Test with neither old nor new config present.
- Test malformed Quickshell user JSON.
- Test repository checkout at a non-default path.
- Confirm `git status` remains clean after normal desktop use.

## Rollback strategy

Until Phase 7, retain the old source files and migration backup.

Rollback consists of:

1. Restore the previous session wrapper.
2. Recreate `~/.config/omd -> <repository>` temporarily.
3. Export `OMD_ROOT=<repository>`.
4. Restart Hyprland/Quickshell.
5. Leave new Sumika config/state directories untouched for investigation.

Never implement rollback by deleting the new directories.

## Completion criteria for the first milestone

The first milestone is complete only when:

- The product-facing name is Sumika Shell.
- `~/.config/sumika-shell` is a real user configuration directory.
- Normal runtime writes do not modify the Git working tree.
- The desktop cold-starts without `~/.config/omd` pointing to the repository.
- User configuration survives restart and repository updates.
- Generated theme, wallpaper, display, and session state are outside Git.
- All acceptance tests pass on at least one fresh login.
- `omd-*` compatibility commands continue to work.

