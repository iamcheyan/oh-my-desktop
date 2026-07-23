# Quickshell Entrypoint Refactor

## Phase 1: Dependency Audit

Audit date: 2026-07-23
Repository root: `~/development/OMD`

### Entry Points Surveyed

| Entry point | Path | shell.qml size | Has app-local symlinks? |
|---|---|---|---|
| **Bar** | `apps/omd-bar/` | ~257 lines | YES (5 symlinks) |
| **Polkit** | `apps/omd-polkit/` | 18 lines | No (flat file copies) |
| **Settings** | `apps/omd-settings/` | ~60 lines | No |
| **Overview** | `modules/overview/` | ~30 lines | No |
| **Launcher** | `modules/launcher/` | ~15 lines | No |
| **Notification** | `modules/notification/` | ~10 lines | No |
| **OSD** | (`on-screen-display` module) | handled via module.json | No |

**Only `apps/omd-bar/` has symlinks.** Other entry points have their own standalone `GlobalStates.qml` copies (minimal).

---

## Symlinks in `apps/omd-bar/`

### 1. `GlobalStates.qml → ../../quickshell/GlobalStates.qml`

**Purpose**: Makes the full `GlobalStates` singleton resolvable in the bar process without QML module import.

**How it's used**: `shell.qml` (and all QML files in the bar process) reference `GlobalStates.*` properties (e.g., `GlobalStates.barPopupType`, `GlobalStates.screenshotActive`). Without the symlink, QML would not find the type since none of the bar's QML files do `import qs`.

**Current imports in `apps/omd-bar/shell.qml`**:
- `import qs.core.runtime`
- `import qs.modules.common`
- `import qs.services`
- `import qs.services as Services`
- `import qs.modules.bar`
- (No `import qs` — this is why the symlink is needed)

**Fix**: Add `import qs` to every QML file in the bar process that references `GlobalStates`. The singleton is already registered at `quickshell/qmldir` as:
```
singleton GlobalStates 1.0 GlobalStates.qml
```
under the `qs` module.

**Consumers** (files in bar process that reference `GlobalStates.*`):
- `apps/omd-bar/shell.qml` (many: barPopupType, screenshotActive, requestSessionConfirm, etc.)
- `quickshell/BarStatusPopup.qml` (via bar process)
- Any bar-side widget referencing GlobalStates

---

### 2. `assets → ../../quickshell/assets`

**Purpose**: Provides `Quickshell.shellPath("assets")` with a real directory.

**How it's used**: Via `Directories.qml`:
```qml
// modules/common/Directories.qml, line 42
property string assetsPath: Quickshell.shellPath("assets")
```

**Consumers**:
- `Directories.assetsPath` → `CosmicIcon.qml` (line 12): builds `"file://" + Directories.assetsPath + "/cosmic-icons/" + name + ".svg"`

**Fix**: Replace `Quickshell.shellPath("assets")` with a path resolved from `Directories.root`:
```qml
property string assetsPath: Quickshell.shellPath("assets")
// → SHOULD become:
property string assetsPath: FileUtils.trimFileProtocol(`${Directories.root}/quickshell/assets`)
```
Where `Directories.root` = `SUMIKA_SHELL_ROOT` env var → `~/.config/omd` (symlink to repo root).

---

### 3. `scripts → ../../quickshell/scripts`

**Purpose**: Provides `Quickshell.shellPath("scripts")` with a real directory.

**How it's used**: Via `Directories.qml`:
```qml
// modules/common/Directories.qml, line 43
property string scriptPath: Quickshell.shellPath("scripts")
```

**Consumers** (directly or via `Directories.scriptPath`):

| File | Usage |
|---|---|
| `Directories.qml` (line 55-56) | `wallpaperSwitchScriptPath = scriptPath + "/colors/switchwall.sh"` |
| `Directories.qml` (line 56) | `recordScriptPath = scriptPath + "/videos/record.sh"` |
| `ScreenshotAction.qml` (lines 81,83) | `Directories.recordScriptPath` → record command |
| `RegionSelection.qml` (line 270) | `Directories.recordScriptPath` → recording stop |
| `KeyringStorage.qml` (line 96) | `${Directories.scriptPath}/keyring/try_lookup.sh` |
| `VoicePage.qml` (lines 591,632,674,682,725) | `${pageRoot.omdRoot}/scripts/voice-*` (hardcoded via omdRoot) |
| `DisplayConfigState.qml` (line 676) | `$HOME/.config/omd/scripts/reload-quickshell` (hardcoded) |

**Fix**: Same approach as `assetsPath`:
```qml
property string scriptPath: FileUtils.trimFileProtocol(`${Directories.root}/quickshell/scripts`)
```

ALSO: replace hardcoded `$HOME/.config/omd/scripts/...` paths with `Directories.root` based paths across all QML files.

---

### 4. `translations → ../../quickshell/translations`

**Purpose**: Provides `Quickshell.shellPath("translations")` with a real directory.

**How it's used**: Via `Translation.qml`:
```qml
// services/Translation.qml, line 22
property string translationsDir: Quickshell.shellPath("translations")
```

**Consumers**: `Translation.qml` only — drives `TranslationScanner` and `TranslationReader` process commands.

**Fix**:
```qml
property string translationsDir: FileUtils.trimFileProtocol(`${Directories.root}/quickshell/translations`)
```

---

### 5. `config.json → ../../defaults/config/quickshell/config.json`

**Purpose**: Default config for the Quickshell process. This is a base config override, not loaded by QML directly.

**How it's used**: The Quickshell startup script (`quickshell/scripts/quickshell`) reads config from `~/.config/sumika-shell/quickshell/config.json` (user config) which the symlink isn't directly needed for — but Quickshell's `-c` flag also resolves config from the project directory.

**Consumers**: None in QML code. The config is consumed by:
- `quickshell/scripts/quickshell` lines 300-301
- `applycolor.sh` line 83
- `record.sh` line 5
- `switchwall.sh` line 13

**Fix**: Not a QML symlink issue. The config is at the user path; the project dir's config.json is a fallback. Can be removed once Quickshell is configured to use the `~/.config/sumika-shell/quickshell/config.json` path exclusively.

---

## GlobalStates Copies in Other Entry Points

| Entry point | File | Contents | Can use `import qs`? |
|---|---|---|---|
| `apps/omd-polkit/` | `GlobalStates.qml` | Empty singleton | Yes — replace with `import qs` |
| `apps/omd-settings/` | `GlobalStates.qml` | Empty singleton | Yes |
| `modules/launcher/` | `GlobalStates.qml` | Empty singleton | Yes |
| `modules/notification/` | `GlobalStates.qml` | `screenLocked` property | Yes |

All should be replaced with `import qs` to use the real `GlobalStates` from the qs module. The real `GlobalStates.qml` is self-contained (no side-effectful constructor).

**Note**: `modules/overview/` does NOT have a local `GlobalStates.qml`. It's unclear how overview resolves `GlobalStates` — possibly via the bar's external module popup staging which runs in the bar process.

---

## `shellPath()` Usage to Eliminate

| File | Line | Code | Replacement |
|---|---|---|---|
| `modules/common/Directories.qml` | 42 | `Quickshell.shellPath("assets")` | `${Directories.root}/quickshell/assets` |
| `modules/common/Directories.qml` | 43 | `Quickshell.shellPath("scripts")` | `${Directories.root}/quickshell/scripts` |
| `services/Translation.qml` | 22 | `Quickshell.shellPath("translations")` | `${Directories.root}/quickshell/translations` |
| `services/ConflictKiller.qml` | 12 | `Quickshell.shellPath("killDialog.qml")` | `${Directories.root}/quickshell/killDialog.qml` |
| `services/FirstRunExperience.qml` | 14 | `Quickshell.shellPath("welcome.qml")` | `${Directories.root}/quickshell/welcome.qml` |

The format `Quickshell.shellPath(...)` resolves paths relative to the Quickshell project directory (where `shell.qml` lives). Since the bar's project dir is `apps/omd-bar/`, the symlinks make this resolve correctly. Without symlinks, `shellPath` would look in the project dir itself.

---

## Module Action Registration in `apps/omd-bar/shell.qml`

`shell.qml` lines 136-226 hardcode `ActionManager.register()` calls for:
- **voice** (voice, sumika-modules)
- **input-method** (input-method, sumika-modules)
- **screenshot** (screenshot, sumika-modules)
- **notification** (notification, OMD modules)
- **app-launcher** (app-launcher, OMD modules)
- **wifi/bluetooth** (wifi, OMD modules)
- **clipboard** (clipboard, sumika-modules)

These should move into their respective module source directories, registered via `ActionManager.register()` in each module's own initialization code. The bar entry point should only register via the registry system.

---

## Hardcoded `$HOME/.config/omd` Paths

Many QML files hardcode `$HOME/.config/omd/bin/...` or `$HOME/.config/omd/scripts/...`. These should use `Directories.root` (which resolves to `SUMIKA_SHELL_ROOT` env var) instead:

| File | Pattern | Count |
|---|---|---|
| `Session.qml` (functions/) | `$HOME/.config/omd/bin/omd-*` | 2 |
| `WorkspaceNavigation.qml` (functions/) | `$HOME/.config/omd/bin/omd-applauncher` | 1 |
| `DisplayConfigState.qml` (settings/display/) | `$HOME/.config/omd/bin/omd-display-config` | 3 |
| `DisplayConfigState.qml` (settings/display/) | `$HOME/.config/omd/scripts/reload-quickshell` | 1 |
| `AppearancePage.qml` (settings/pages/) | `$HOME/.config/omd/bin/omd-*` | 8 |
| `VoicePage.qml` (settings/pages/) | `$HOME/.config/omd/scripts/voice-*` | 5 |
| `WindowsVmPage.qml` (settings/pages/) | `$HOME/.config/omd/bin/omd-settings-windows-vm` | 6 |
| `Brightness.qml` (services/) | `$HOME/.config/omd/bin/omd-ddc-detect` | 1 |
| `Network.qml` (services/) | `$HOME/.config/omd/bin/omd-network-*` | 3 |
| `VoiceInput.qml` (services/) | `$HOME/.config/omd/apps/omd-bar ipc call` | 1 |

These are NOT blocking the symlink removal — they reference `~/.config/omd` which is a stable symlink to the repo root. They should still be migrated for consistency.

---

## Phase Plan

| Phase | Scope | Changes |
|---|---|---|
| **1** | ✅ **Done** | Dependency audit (this document) |
| **2** | Centralize resource paths | Replace `shellPath()` in `Directories.qml`, `Translation.qml`, `ConflictKiller.qml`, `FirstRunExperience.qml` with paths from `Directories.root` |
| **3** | Import GlobalStates via `qs` | Add `import qs` to bar process QML files; remove `GlobalStates.qml` symlink and all standalone `GlobalStates.qml` copies |
| **4** | Move action registration to modules | Move `_registerModuleActions()` block from `shell.qml` into each module's own initialization |
| **5** | Remove legacy symlinks | Delete the 5 symlinks in `apps/omd-bar/` after all consumers are migrated |
| **6** | Clean up startup wrappers | Update `quickshell.sh` if needed; remove dead code |
