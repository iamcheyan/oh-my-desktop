# Commit Groups — Module Split Organization

Based on the current state of branch `module-split` (at `126b8ca`) plus the
changes made in this session. The work naturally divides into logical commit
groups. Files listed are those modified in this session only; files from prior
batches are already committed.

## Batch 3: Config, Docs, and Stale Code Cleanup

This batch covers all the documentation updates, configuration fixes, and
dead-code cleanup after the feature module migration.

### Commit 3a: Fix config comments and init instructions

- `Init.sh` — Add sumika-modules clone note to header and `print_summary`
- `quickshell/modules/common/Config.qml` — Fix product-floor comment
  (add "launcher", fix "workspace" → "workspaces", "power" → "power-indicator")

### Commit 3b: Remove dead shared/ QML module

- `shared/` (entire directory) — Dead code (`qs.shared` module, zero runtime
  consumers, all imports migrated to `quickshell/modules/common/` equivalents)

Note: also removes `shared/Config.qml` (duplicate of common/Config.qml),
`shared/TuiStyle.qml` (duplicate of common/TuiStyle.qml), etc.

### Commit 3c: Update architecture documentation

- `AGENTS.md` — Correct QML module count (7→4), reflect QML import module moves
- `modules/README.md` — Correct QML module count
- `docs/project-structure.md` — Rewrite root table, running processes, shared UI
  components, Where Changes Belong, Bar Widget Registry for current reality
- `docs/core-allowlist.md` — New file: definitive Core allowlist
- `docs/module-split-services-remaining.md` — Update to reflect QML import moves,
  shared/ deletion, and final state

## Prior Batches (Already Committed or Staged)

### Batch 1 (committed as `126b8ca` and ancestors)

Module migration: all 10 product-floor modules moved from OMD/modules/ to
sumika-modules/. Bin shims created, QML references fixed, Config updates,
starter documentation updated.

### Batch 2 (staged — Phase C continued)

Settings page migration, QML import module moves (notificationPopup,
onScreenDisplay, overview), settings cleanup, scripts cleanup.

## Verification Checklist (Pre-commit)

- [x] `omd-doctor` passes (2 non-critical: Go tools build, GNOME Keyring PAM)
- [x] `omd-module-validate --all`: 27/27 pass, 0 warn, 0 fail
- [x] OMD/modules/ empty (README only)
- [x] Zero stale `OMD/modules/X/` references in QML, shell scripts, Lua, Python
- [x] Zero stale `quickshell/modules/{notificationPopup,onScreenDisplay,overview}` refs
- [x] 27 unique module IDs in sumika-modules, zero duplicates with OMD
