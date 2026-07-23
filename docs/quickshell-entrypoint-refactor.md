# Quickshell Entrypoint Refactor

## Architecture

### Before

```
apps/omd-bar/
├── config.json → ../../defaults/config/quickshell/config.json  (symlink)
├── shell.qml            (257 lines, hardcoded ActionManager.register() calls)
├── GlobalStates.qml → ../../quickshell/GlobalStates.qml         (symlink)
├── assets → ../../quickshell/assets                             (symlink)
├── scripts → ../../quickshell/scripts                           (symlink)
└── translations → ../../quickshell/translations                 (symlink)
```

Other entry points (`omd-polkit`, `omd-settings`, `modules/launcher`, `modules/notification`) carried standalone `GlobalStates.qml` copies.

### After

```
apps/omd-bar/
└── shell.qml            (159 lines, no symlinks, thin entry point)
```

All project-directory symlinks removed. Resources resolved via `Directories.root` (evaluates `SUMIKA_SHELL_ROOT` → `~/.config/omd` → repo root). GlobalStates resolved via official `import qs` module. Module actions registered per-module in `module-actions.qml` files, loaded by `ModuleActionHost`.

---

## Entry Points Surveyed

| Entry point | Path | shell.qml size | Symlinks (before) | Symlinks (after) |
|---|---|---|---|---|
| **Bar** | `apps/omd-bar/` | 159 lines | 5 | 0 |
| **Polkit** | `apps/omd-polkit/` | 18 lines | GlobalStates copy | 0 |
| **Settings** | `apps/omd-settings/` | ~60 lines | GlobalStates copy | 0 |
| **Overview** | `modules/overview/` | ~30 lines | 0 | 0 |
| **Launcher** | `modules/launcher/` | ~15 lines | GlobalStates copy | 0 |
| **Notification** | `modules/notification/` | ~10 lines | GlobalStates copy | 0 |
| **OSD** | `on-screen-display` module | via module.json | 0 | 0 |

---

## Changes Per Phase

### Phase 2: Resource Paths Unified

All `Quickshell.shellPath()` calls replaced with `Directories.root`-based paths.

`Directories.root` resolves: `SUMIKA_SHELL_ROOT` env var → `~/.config/omd` (symlink to repo root). This is a stable path independent of the Quickshell project directory.

**Files changed:**
- `modules/common/Directories.qml` — assetsPath, scriptPath
- `services/Translation.qml` — translationsDir
- `services/ConflictKiller.qml` — killDialog path
- `services/FirstRunExperience.qml` — welcome path

### Phase 3: GlobalStates via `import qs`

The `GlobalStates` singleton is registered in `quickshell/qmldir` under the `qs` module:

```
singleton GlobalStates 1.0 GlobalStates.qml
```

Added `import qs` to every entry point shell.qml that previously relied on a local copy. Removed all 5 GlobalStates files:
- `apps/omd-bar/GlobalStates.qml` (symlink)
- `apps/omd-polkit/GlobalStates.qml` (flat file)
- `apps/omd-settings/GlobalStates.qml` (flat file)
- `modules/launcher/GlobalStates.qml` (flat file)
- `modules/notification/GlobalStates.qml` (flat file)

### Phase 4: Module Action Self-Registration

Core provides `ModuleActionHost` (`quickshell/core/runtime/ModuleActionHost.qml`):

```qml
Item {
    Repeater {
        model: ModuleLoader._registry.modules
            .filter(m => m.id && m.path && ModuleLoader.isEnabled(m.id))
            .map(m => ({ moduleId: m.id, actionsUrl: "file://" + m.path + "/module-actions.qml" }))
        delegate: Loader { source: actionsUrl; asynchronous: true }
    }
}
```

Each module places `module-actions.qml` in its root directory. ModuleActionHost loads it for every enabled module.

`ActionManager.qml` changes:
- **Removed** `_registerModuleActions()` — 18 module-specific `register()` calls (~100 lines)
- **Removed** `_registerClipboardActions()` — 6 clipboard actions (~35 lines)
- **Retained** `_registerBuiltins()` — `session.*`, `settings.open`, `overview.open`, `shell.reload`, `process_supervisor.*`, `bluetooth.launch`
- **Added** dynamic enable check: `isAvailable()` and `invoke()` both call `ModuleLoader.isEnabled(owner)` — non-core actions are disabled at runtime when the owning module is disabled

#### Module action registration matrix

| Module | Actions registered | Location |
|---|---|---|
| voice | `voice.toggle`, `voice.cancel` | `modules/voice/module-actions.qml` |
| screenshot | `screenshot.freeze/unfreeze/capture/capture-edit/capture-ocr` | `modules/screenshot/module-actions.qml` |
| notification | `notification.dismiss-last/dismiss-all/toggle-silent/edit-muted` | `modules/notification/module-actions.qml` |
| input-method | `input-method.cycle` | `modules/input-method/module-actions.qml` |
| app-launcher | `app-launcher.toggle` | `modules/app-launcher/module-actions.qml` |
| wifi | `wifi.launch` | `modules/wifi/module-actions.qml` |
| clipboard (external) | `clipboard.store-toggle/toggle/toggleBar/open/close/paste` | `sumika-modules/clipboard/module-actions.qml` |
| bluetooth | `bluetooth.launch` | Builtin in `ActionManager._registerBuiltins()` |

Modules without QML-callback actions (audio, battery-power, clock, display, launcher, mpris, notification-popup, on-screen-display, overview, session, sidebar-indicators, systray, workspaces) have empty `module-actions.qml` files to suppress Loader warnings.

### Phase 5: Symlinks Removed

Deleted all 4 symlinks from `apps/omd-bar/`:
1. `GlobalStates.qml` — replaced by `import qs`
2. `assets` — replaced by `Directories.root + "/quickshell/assets"`
3. `scripts` — replaced by `Directories.root + "/quickshell/scripts"`
4. `translations` — replaced by `Directories.root + "/quickshell/translations"`
5. (Later) `config.json` — Quickshell reads config from `~/.config/sumika-shell/quickshell/config.json`; the project-level fallback was unnecessary

### Phase 6: Startup Wrapper Audit

Audited `quickshell/scripts/quickshell` (~390 lines):

- `_register_path()`: Sets `OMD_APP_DIR` and `QS_CONFIG_DIR` for module runtime paths — non-QML, retained
- `repair_config_json()`: Copies default config to `~/.config/sumika-shell/quickshell/config.json` — unrelated to project symlink, retained
- QML import root staging: Sets up transient import root at `$XDG_RUNTIME_DIR/sumika-shell/qml/qs` → repo `quickshell/` — handles external module staging, retained

No stale compat code identified that could be removed without breaking the shell launch flow.

---

## Module Disable Architecture

Module enable/disable flows through `ModuleLoader`:

```
sumika.json → Config.qml → ModuleLoader
                             ├── modulesEnabled (reactive boolean)
                             ├── isEnabled(id) → checks master + disabled list
                             ├── popupSections, overlays, settingsPages, etc.
                             └── activeModuleIds
```

`ModuleActionHost` calls `ModuleLoader.isEnabled()` before loading each module's `module-actions.qml`. `ActionManager.isAvailable()` / `invoke()` also call it — so actions from disabled modules are unreachable even if registered before the disable event.

Gates exist at every extension point:
- `ModuleActionHost` — no module-actions.qml loaded
- `ModuleLoader.popupSections` — no popups registered
- `ModuleLoader.overlays` — no overlays shown
- `ModuleLoader.settingsPages` — no settings pages available
- `ModuleLoader.overviewProviders` — no overview providers
- `ModuleLoader.activeModuleIds` — module removed from active list

Physical tests confirmed:
- `modules.enabled = false` → 0 module actions, only builtins remain
- `modules.disabled = ["voice"]` → 0 voice actions, all other modules unaffected


---

## QML Import Root Mechanism

Quickshell resolves `import qs.services` as `<QML_IMPORT_PATH>/qs/services`. Since the source
directory is named `quickshell/`, adding the repo root to `QML_IMPORT_PATH` directly would not
make `import qs` work — hence the transient import root.

### Setup (in `quickshell/scripts/quickshell`)

```
runtime_base="$XDG_RUNTIME_DIR/sumika-shell"
qml_import_root="$runtime_base/qml"
ln -sfn "$repo_root/quickshell" "$qml_import_root/qs"
export QML_IMPORT_PATH="$qml_import_root"
```

This creates a symlink `$XDG_RUNTIME_DIR/sumika-shell/qml/qs → repo/quickshell/`. Quickshell
then resolves `import qs.modules.bar` as `$qml_import_root/qs/modules/bar/qmldir` → the actual
`quickshell/modules/bar/` directory.

### External module import root

For modules in `sumika-modules/` (separate repo), each external module's `bar/` subdirectory
is symlinked into a staging area under `$runtime_base/staging/<process>_/external-modules/`.
These staging links are prepended to `QML_IMPORT_PATH` so `import qs.modules.<name>` resolves
to the external module before checking OMD's built-in modules.

### Default OMD module import

Modules under `modules/` (built-in OMD modules like `bar`, `clock`, `workspaces`) are added
to `QML_IMPORT_PATH` by the startup script so their `qmldir` files are discoverable.
These come after external modules in the path order, so external modules take priority.

---

## `qmldir` Module Registration

The `qs` module is registered in `quickshell/qmldir`:

```
module qs
singleton GlobalStates 1.0 GlobalStates.qml
```

Because `QML_IMPORT_PATH` points to the repo's `quickshell/` directory as the `qs` module
root, this `qmldir` is found automatically. Any QML file in any process can do:

- `import qs` → makes `GlobalStates` available
- `import qs.core.runtime` → `quickshell/core/runtime/qmldir` (ActionManager, ModuleActionHost, etc.)
- `import qs.services` → `quickshell/services/qmldir` (VoiceInput, Notifications, etc.)
- `import qs.modules.common` → `quickshell/modules/common/qmldir` (Directories, TuiStyle, etc.)
- `import qs.modules.bar` → `quickshell/modules/bar/qmldir` (Bar, SysTray, etc.)

Each subdirectory with a `qmldir` acts as its own QML module under the `qs` module namespace.

---

## Entry Point Responsibility Boundaries

Each Quickshell process has a thin `shell.qml` with strict boundaries:

### What a shell.qml MUST do:
- Create a `ShellRoot` as the top-level QML component
- Launch the process-specific runtime infrastructure (bar: `Bar`, `ModuleActionHost`; overview: search panel)
- Provide IPC handlers for cross-process communication (via `IpcHandler` with unique `target`)
- Load dynamic overlays from `ModuleLoader.overlays`

### What a shell.qml MUST NOT do:
- `ActionManager.register()` for module-specific actions (done by `module-actions.qml`)
- Hardcode module-specific logic (no `if module=="voice"`)
- Reference module-internal components directly
- Load QML files by app-local symlinks

### IPC handler rules:
- IPC handlers call `ActionManager.invoke()` for module actions — they do not bypass
  `ModuleLoader.isEnabled()` checks
- Each IPC handler has a unique `target` name (e.g., `"voice"`, `"screenshot"`, `"menus"`)
- The `"action"` target provides a generic dispatch layer for cross-process action calls

---

## GlobalStates Process Isolation

`GlobalStates` is a QML singleton registered in `quickshell/qmldir`:

```
singleton GlobalStates 1.0 GlobalStates.qml
```

**Each Quickshell process has its own independent instance of `GlobalStates`.**

This is a fundamental QML singleton behavior: singletons are per-engine-instance.
Since each `shell.qml` runs in a separate `quickshell` OS process (started by systemd),
their `GlobalStates` singletons are completely isolated.

### Cross-process communication:

| Mechanism | When to use |
|---|---|
| **IPC (qs -p ... ipc call)** | Direct action invocation, menu control |
| **File state** | Shared state like wallpaper path, theme |
| **DBus services** | System services (Polkit, MPRIS, Notifications) |
| **ActionManager IPC** | `bin/omd-action call <id>` or `qs -p ... ipc call action call <id>` |

### Before the refactor:
Previous code sometimes assumed `GlobalStates.screenshotActive` or `GlobalStates.barPopupType`
was shared between the bar process and screenshot process — this was never guaranteed and could
cause race conditions. Now all cross-process coordination goes through `ActionManager.invoke()` or
explicit IPC (`qs -p apps/omd-bar ipc call...`).

---

## Module Registration Mechanism

Modules register their QML-callback actions through a uniform mechanism:

### 1. `module-actions.qml`

Each module places a `module-actions.qml` file in its root directory. This file imports
`qs.core.runtime` and calls `ActionManager.register()`:

```qml
// modules/voice/module-actions.qml
import QtQuick
import qs.core.runtime

Item {
    Component.onCompleted: {
        ActionManager.register("voice.toggle", "voice", "Toggle voice recording", {
            type: "qml",
            callback: () => Svcs.VoiceInput.toggle()
        })
    }
}
```

### 2. `ModuleActionHost`

`ModuleActionHost` (one instance in the bar process, inside the main Scope) iterates
`ModuleLoader._registry.modules`, checks `ModuleLoader.isEnabled(m.id)`, and loads each
enabled module's `module-actions.qml` via a `Loader`:

```qml
Repeater {
    model: ModuleLoader._registry.modules
        .filter(m => m.id && m.path && ModuleLoader.isEnabled(m.id))
        .map(m => ({ moduleId: m.id, actionsUrl: "file://" + m.path + "/module-actions.qml" }))
    delegate: Loader { source: actionsUrl; asynchronous: true }
}
```

### 3. Module disable cleanup

When a module is disabled (or `modules.enabled` becomes `false`), the QML `Repeater` model
re-evaluates, the `Loader` is destroyed, and `Component.onDestruction` fires
`ActionManager.unregisterOwner(moduleId)` — automatically cleaning up all actions from
that module.

### 4. Builtin actions

Actions without a module directory (e.g., `bluetooth.launch` — launched via
`bin/omd-launch-bluetooth`, a standalone script) remain registered in
`ActionManager._registerBuiltins()`.
---

## Hardcoded `~/.config/omd` Paths (Cosmetic)

Many QML files hardcode `$HOME/.config/omd/bin/...` or `$HOME/.config/omd/scripts/...`. These use `Directories.root` (which resolves to the same symlink) and are NOT blocking — the symlink is stable. Listed for future migration.

| File | Pattern | Count |
|---|---|---|
| `Session.qml` | `$HOME/.config/omd/bin/omd-*` | 2 |
| `WorkspaceNavigation.qml` | `$HOME/.config/omd/bin/omd-applauncher` | 1 |
| `DisplayConfigState.qml` | `$HOME/.config/omd/bin/omd-display-config` / scripts | 4 |
| `AppearancePage.qml` | `$HOME/.config/omd/bin/omd-*` | 8 |
| `VoicePage.qml` | `$HOME/.config/omd/scripts/voice-*` | 5 |
| `WindowsVmPage.qml` | `$HOME/.config/omd/bin/omd-settings-windows-vm` | 6 |
| `Brightness.qml` | `$HOME/.config/omd/bin/omd-ddc-detect` | 1 |
| `Network.qml` | `$HOME/.config/omd/bin/omd-network-*` | 3 |
| `VoiceInput.qml` | `$HOME/.config/omd/apps/omd-bar ipc call` | 1 |

---

## Hardcoded `$HOME/development/OMD` Paths in QML

Some QML files reference `$HOME/development/OMD` (the repo path as seen by the developer). These are environment-specific and should be migrated to `Directories.root`:

*(list here if grep finds any)*

---

## Git History

### OMD repository (`~/development/OMD`)

```
c46354f — Phase 2+3: Unified resource paths + removed GlobalStates copies (Phase 3)
f1b9c96 — Phase 4: ModuleActionHost + per-module module-actions.qml + ActionManager refactor
80f6222 — Phase 5: Deleted omd-bar symlinks (assets, scripts, translations)
4496bb8 — Phase 6: Empty module-actions.qml + import QtQuick fix + Loader error handling
1c6b3ba — Docs: Audit + verification docs
```

Plus subsequent work:
```
c2a4286 — Final: Deleted config.json symlink, updated docs with actual implementation
```

### Sumika-modules repository (`~/development/sumika-modules`)

```
793e1f0 — Added module-actions.qml for all 10 external modules
```
