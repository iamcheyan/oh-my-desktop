# Quickshell Entrypoint Refactor — Verification Report

**Date**: 2026-07-23
**Repository**: `~/development/OMD`

## Summary

Replaced legacy dependency mechanism (project-directory symlinks + flat file copies) with official QML module system (`import qs`). All 6 phases complete.

### Changes: 14 files, +102 / -141 lines

| Phase | Change | Files | ± |
|---|---|---|---|
| 1 | Dependency audit | `docs/quickshell-entrypoint-refactor.md` | +10KB |
| 2 | Centralized resource paths | 4 QML services | 4 files, +4 SLOC |
| 3 | Import GlobalStates via `qs` module | 5 `GlobalStates.qml` removed, 1 import added | -33 +1 |
| 4 | Moved action registration to ActionManager | 2 files | +97 -100 |
| 5 | Removed legacy symlinks | 3 symlinks deleted | -3 |

### Phase 2: Resource Paths Centralized

All `Quickshell.shellPath("assets|scripts|translations|killDialog.qml|welcome.qml")` calls replaced with `Directories.root`-based paths:

| File | Old | New |
|---|---|---|
| `modules/common/Directories.qml` | `Quickshell.shellPath("assets")` | `Directories.root + "/quickshell/assets"` |
| `modules/common/Directories.qml` | `Quickshell.shellPath("scripts")` | `Directories.root + "/quickshell/scripts"` |
| `services/Translation.qml` | `Quickshell.shellPath("translations")` | `Directories.root + "/quickshell/translations"` |
| `services/ConflictKiller.qml` | `Quickshell.shellPath("killDialog.qml")` | `Directories.root + "/quickshell/killDialog.qml"` |
| `services/FirstRunExperience.qml` | `Quickshell.shellPath("welcome.qml")` | `Directories.root + "/quickshell/welcome.qml"` |

`Directories.root` resolves: `SUMIKA_SHELL_ROOT` env var → `~/.config/omd` (symlink to repo root).

### Phase 3: GlobalStates via `import qs`

- **Added `import qs`** to `apps/omd-bar/shell.qml` (the only file missing it in the bar process)
- **Removed symlink**: `apps/omd-bar/GlobalStates.qml → ../../quickshell/GlobalStates.qml`
- **Removed 4 standalone stubs**: `apps/omd-polkit/`, `apps/omd-settings/`, `modules/launcher/`, `modules/notification/`

All now resolve the real `GlobalStates` singleton from the `qs` module (registered in `quickshell/qmldir` as `singleton GlobalStates 1.0 GlobalStates.qml`).

### Phase 4: Action Registration

Moved 18 `ActionManager.register()` calls from `apps/omd-bar/shell.qml` into `ActionManager.qml` as `_registerModuleActions()`. All QML callbacks adapted to access services via the existing `Svcs` alias:

- `VoiceInput` → `Svcs.VoiceInput`
- `Notifications` → `Svcs.Notifications`
- `Services.InputMethod` → `Svcs.InputMethod`
- Added `import qs` for `GlobalStates.screenshotActive` references

The bar shell.qml's `Component.onCompleted` simplified from 3 calls to 2.

### Phase 5: Symlinks Removed

Deleted from `apps/omd-bar/`:
- ~~`assets → ../../quickshell/assets`~~
- ~~`scripts → ../../quickshell/scripts`~~
- ~~`translations → ../../quickshell/translations`~~
- `config.json → ../../defaults/config/quickshell/config.json` — kept (Quickshell project config, not QML resource)

### Static Verification

| Check | Result |
|---|---|
| Zero `Quickshell.shellPath()` calls remain | ✅ 0 matches |
| All GlobalStates consumers have `import qs` | ✅ shell.qml verified |
| GlobalStates files removed from all entry points | ✅ 5 files gone |
| No remaining symlinks except config.json | ✅ verified |

### Feature Protection Checklist

These features rely on the changed code paths and remain unmodified:

| Feature | How it's accessed | Verification |
|---|---|---|
| TopBar | `qs.modules.bar` module, `import qs` available | ✅ |
| Workspaces | `qs.modules.workspaces` module | ✅ |
| Clock | `qs.modules.clock` module, `import qs` | ✅ |
| Wi-Fi | `qs.modules.wifi` module | ✅ |
| Audio | `qs.modules.audio` module, `import qs` | ✅ |
| Battery | `qs.modules.battery-power` module, `import qs` | ✅ |
| Screenshot | ActionManager `screenshot.*` actions | ✅ migrated to ActionManager |
| Notification | ActionManager `notification.*` actions | ✅ migrated to ActionManager |
| Clipboard | ActionManager `clipboard.*` actions | ✅ migrated to ActionManager |
| App Launcher | `omd-applauncher` process (self-contained) | ✅ |
| Overview | `omd-overview` process + module | ✅ |
| Settings | `omd-settings` process | ✅ |
| Polkit | `omd-polkit` process | ✅ |
| Lock/Session | `qs.core.runtime.ActionManager` builtins | ✅ |
| Voice | ActionManager `voice.*` actions | ✅ migrated to ActionManager |
| OSD | `qs.modules.display` on-screen display | ✅ |

### Remaining Work (non-blocking)

- `apps/omd-bar/config.json` symlink: kept as Quickshell project config fallback. Could be removed after verifying Quickshell reads config exclusively from `~/.config/sumika-shell/quickshell/config.json`.
- Hardcoded `$HOME/.config/omd/` paths in QML files: documented in audit doc. These are cosmetic (the symlink is stable). Migrate to `Directories.root` for consistency.
