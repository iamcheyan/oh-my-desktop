# Module Split — Services & Remaining Items

## Completed

### Phase A: Freeze Inventory
- Mapped all OMD/modules/ → 10 product-floor modules identified for external migration
- Mapped quickshell/modules/ (shared QML imports)
- Mapped apps/, bin/, quickshell/services/, external modules state
- Ownership matrix written (see below)

### Ownership Matrix (Phase A output)

#### apps/
| Directory | Classification | Reason |
|-----------|---------------|--------|
| `apps/omd-bar/` | **CORE** | TopBar host process. Architecture-defined Core. |
| `apps/omd-polkit/` | **CORE** | PolicyKit authentication agent. Core infrastructure. |
| `apps/omd-settings/` | **CORE** | Settings window host (hosts Core SettingsDialog). 101-line shell.qml imports only Core `qs.modules.settings`. |

#### quickshell/modules/
| Directory | Classification | Reason |
|-----------|---------------|--------|
| `quickshell/modules/bar/` | **CORE** | TopBar UI host (Bar, BarContent, BarStatusPopup shell, DismissLayer). No business overlay. |
| `quickshell/modules/common/` | **SHARED_PRIMITIVE** | TuiStyle, Config, Directories, Appearance, PanelWindow, shared widgets. No business ownership. |
| `quickshell/modules/polkit/` | **CORE** | PolicyKit UI components. |

#### quickshell/core/
| Path | Classification | Reason |
|------|---------------|--------|
| `quickshell/core/runtime/` | **CORE** | ModuleLoader, ActionManager, ServiceManager, ProcessSupervisor, ApplicationManager |
| `quickshell/core/api/` | **CORE** | ActionApi, ServiceApi, ActionEncoder, schemas |
| `quickshell/core/ui/` | **CORE** | TopBar host, Overview host |
| `quickshell/core/layout/` | **CORE** | Shell layout module |
| `quickshell/core/diagnostics/` | **CORE** | DiagnosticReporter |
| `quickshell/core/GlobalStates.qml` | **CORE** | Session-wide global state |

#### quickshell/services/ (all 29 — transitional)

All services are **CORE (transitional)** — system-level singletons exposed via ServiceManager.
Allowable temporary location per §1.4. No UI/business modules in OMD.

| # | Service | Classification | Reason |
|---|---------|---------------|--------|
| 1 | `AppSearch.qml` | CORE (transitional) | App search singleton |
| 2 | `Audio.qml` | CORE (transitional) | Audio sink control singleton |
| 3 | `Battery.qml` | CORE (transitional) | Battery status singleton |
| 4 | `BluetoothStatus.qml` | CORE (transitional) | Bluetooth adapter singleton |
| 5 | `Brightness.qml` | CORE (transitional) | Display brightness singleton |
| 6 | `ConflictKiller.qml` | CORE (transitional) | Config conflict resolution |
| 7 | `DateTime.qml` | CORE (transitional) | Date/time tracking singleton |
| 8 | `FirstRunExperience.qml` | CORE (transitional) | First-run setup singleton |
| 9 | `GlobalFocusGrab.qml` | CORE (transitional) | Focus management singleton |
| 10 | `HyprlandData.qml` | CORE (transitional) | Hyprland IPC data bridge |
| 11 | `HyprlandXkb.qml` | CORE (transitional) | Keyboard layout singleton |
| 12 | `Hyprsunset.qml` | CORE (transitional) | Blue-light filter singleton |
| 13 | `Idle.qml` | CORE (transitional) | Idle detection singleton |
| 14 | `InputMethod.qml` | CORE (transitional) | Input method singleton |
| 15 | `KeyboardRemap.qml` | CORE (transitional) | Keyboard remap singleton |
| 16 | `KeyringStorage.qml` | CORE (transitional) | Secret storage singleton |
| 17 | `LockService.qml` | CORE (transitional) | Session lock singleton |
| 18 | `MprisController.qml` | CORE (transitional) | MPRIS media control singleton |
| 19 | `Network.qml` | CORE (transitional) | Network configuration singleton |
| 20 | `Notifications.qml` | CORE (transitional) | Notification daemon singleton |
| 21 | `OmarchyTheme.qml` | CORE (transitional) | Theme management singleton |
| 22 | `PolkitService.qml` | CORE (transitional) | PolicyKit auth singleton |
| 23 | `PowerProfiles.qml` | CORE (transitional) | Power profile singleton |
| 24 | `SystemInfo.qml` | CORE (transitional) | System info singleton |
| 25 | `TrackArt.qml` | CORE (transitional) | Album art fetch singleton |
| 26 | `TrayService.qml` | CORE (transitional) | System tray singleton |
| 27 | `Updates.qml` | CORE (transitional) | Update check singleton |
| 28 | `VoiceInput.qml` | CORE (transitional) | Voice input singleton |
| 29 | `Wallpaper.qml` | CORE (transitional) | Wallpaper singleton |

#### bin/omd-*
| Script | Classification | Reason |
|--------|---------------|--------|
| `omd-action` | **CORE** | Route Hyprland bindings through ActionManager IPC |
| `omd-detach` | **CORE** | Process detachment utility for transient services |
| `omd-doctor` | **CORE** | Runtime dependency and config diagnostic |
| `omd-kitty-smart-paste` | **CORE** | Terminal paste helper |
| `omd-module-validate` | **CORE** | Module manifest validation (Python, schema-driven) |
| `omd-modules` | **CORE** | Module lifecycle management |
| `omd-restart` | **CORE** | Quickshell lifecycle management |
| `omd-screenshot` | **CORE** | Screenshot tool |
| `omd-theme-bg-set` | **CORE** | Theme background setter |
| `omd-wallpaper` | **CORE** | Wallpaper renderer/rotation |
| `omd-settings` | **SHIM→module** | 7-line exec shim → `$SUMIKA_MODULES_HOME/settings/bin/omd-settings` (formerly 112-line script with page routing + Wayland discovery) |
| `omd-settings-tui` | **SHIM→module** | TUI settings page router (46 lines, routes to external module bins) |
| `omd-applauncher` | **SHIM→module** | 10-line exec → `$SUMIKA_MODULES_HOME/launcher/bin/omd-applauncher` (dead OMD/modules fallback removed) |
| `omd-applauncher-cache` | **SHIM→module** | 10-line exec → `$SUMIKA_MODULES_HOME/launcher/bin/omd-applauncher-cache` (dead OMD/modules fallback removed) |
| `omd-bar` | **SHIM** | 7-line QML process launcher for bar |
| `omd-polkit` | **SHIM** | 7-line QML process launcher for polkit |
| `omd-paste-at-cursor` | **SHIM→module** | 3-line exec to voice module |
| `omd-powerprofiles-init` | **SHIM→module** | 4-line exec to battery-power module |
| `omd-hyprland-*` (10 scripts) | **SHIM→omarchy** | 2-line exec to `share/bin/omarchy-*` |
| `omd-launch-or-focus*` (3 scripts) | **SHIM→omarchy** | 2-line exec to `share/bin/omarchy-*` |
| `omd-launch-*` (2 scripts) | **SHIM→omarchy** | 2-line exec to `share/bin/omarchy-*` |
| `omd-lock`, `omd-logout` | **SHIM→omarchy** | 2-line exec to `share/bin/omarchy-*` |
| `omd-toggle-touchpad` | **SHIM→omarchy** | 2-line exec to `share/bin/omarchy-*` |
| `omd-wake` | **SHIM→omarchy** | 2-line exec to `share/bin/omarchy-*` |
| `omd-hw-external-monitors` | **SHIM→omarchy** | 2-line exec to `share/bin/omarchy-*` |

#### OMD/modules/ (should be empty)
| Status | |
|--------|--|
| **EMPTY** | Only `README.md` remains. No functional module packages. |

#### External modules in $SUMIKA_MODULES_HOME (27 total)
| Category | Module IDs |
|----------|-----------|
| **FLOOR_MODULE** (10) | launcher, clock, notification-popup, workspaces, overview, systray, wifi, audio, power-indicator, display |
| **OPTIONAL_MODULE** (17) | active-window, battery-power, brightness-gamma, clipboard, file-backup, input-method, keyboard-remap, mpris, notification, ocr, on-screen-display, popup-components, screenshot, session, settings, voice, windows-vm |

### Phase B: External Module Migration (10 modules)
All migrated from `OMD/modules/` to `$SUMIKA_MODULES_HOME` (sumika-modules/):

1. launcher — bin shims created (omd-applauncher, omd-applauncher-cache), QML paths fixed
2. clock — simple copy/delete (no external QML refs)
3. notification-popup — simple copy/delete
4. power-indicator — simple copy/delete
5. systray — simple copy/delete
6. workspaces — simple copy/delete
7. audio — QML refs fixed (ActionManager.qml), bin script hardened (omd-swayosd-client)
8. display — QML refs fixed (DisplayConfigState.qml, Brightness.qml), bin paths updated
9. overview — bin script hardened (omd-overview prefers SUMIKA_MODULES_HOME)
10. wifi — QML refs fixed (ActionManager.qml, BluetoothStatus.qml, Network.qml, WifiPopup.qml, module-actions.qml)

### Phase C: Clean OMD Business Tree (batch 1 — settings migration)
- Settings pages for now-external modules: all 10 product-floor modules now register `settingsPages` in `module.json`:
  - display (`id: "display"`, fixed from `"display-settings"`)
  - battery-power (`id: "power"`)
  - keyboard-remap (`id: "keyremap"`)
  - windows-vm (`id: "windows-vm"`)
  - voice (`id: "voice"`)
  - wifi (`id: "network"`)
  - audio (`id: "sound"`, `"bluetooth"`)
- Hardcoded fallback Components removed from SettingsDialog.qml (networkPage, bluetoothPage — now resolved via ModuleLoader)
- OMD duplicates deleted: SettingsDialog now checks module pages first, then Core pages
- Duplicate settings pages deleted from OMD: PowerPage, KeyboardRemapPage, VoicePage, WindowsVmPage, display/ subdirectory (7 files), NetworkPage, BluetoothPage, SoundPage
- qmldir pruned: only OverviewPage, AppearancePage, SystemPage, KeyboardEditorOverlay remain (Core only)
- Orphan ModulesPage.qml deleted (dead code, never in qmldir or SettingsDialog)
- quickshell/scripts/quickshell: removed OMD/modules/ scan blocks (2 sections) — no functional modules remain in OMD/modules/
- BluetoothStatus.qml: fixed stale path fallback (`Directories.root + "/modules/wifi/bin"` → `$HOME/development/sumika-modules/wifi/bin`)
- AGENTS.md, modules/README.md updated, docs/module-split-services-remaining.md refreshed

### Phase C (batch 2 — QML import module moves)
- notificationPopup QML import: `OMD/quickshell/modules/notificationPopup/` → `sumika-modules/notification-popup/`. Thin shell replaced with real implementation. OMD original deleted.
- onScreenDisplay QML import: `OMD/quickshell/modules/onScreenDisplay/` → `sumika-modules/on-screen-display/`. Thin shell replaced. qmldir created. OMD original deleted.
- overview QML import: `OMD/quickshell/modules/overview/` → `sumika-modules/overview/`. qmldir created. OMD original deleted.
- overview/module.json entry path fixed: `${OMD_ROOT}/modules/overview/bin/omd-overview` → `omd-overview` (matches launcher/notification pattern using PATH)

### Phase D: Discovery & Floor Config
- Empty OMD/modules/ verified ✅
- 27 sumika-modules, 0 duplicates ✅
- omd-module-validate --all: 27/27 passed ✅
- product-floor module IDs verified (Config.qml, omd-restart, ModuleLoader)
- Stale OMD/modules/X/ paths grep: zero actionable hits ✅
- AGENTS.md updated, Init.sh updated
-
## Current State After All Phases

### OMD/quickshell/modules/ (4 Core shared QML libraries)
- bar — TopBar host
- common — shared widgets (TuiStyle, PanelWindow, etc.)
- settings — SettingsDialog, SettingsTokens, page widget primitives
- polkit — PolicyKit agent

### OMD/modules/
Empty (README.md only).

### QML import modules moved to sumika-modules
notificationPopup (`qs.modules.notificationPopup`), onScreenDisplay (`qs.modules.onScreenDisplay`),
and overview (`qs.modules.overview`) QML types now live in their respective sumika-modules dirs.
The qmldir files ship in the module directory so `QML_IMPORT_PATH` resolution works.

### Settings page resolution (SettingsDialog)
1. Module-provided pages via `ModuleLoader.settingsPages` (resolved first)
2. Core hardcoded pages: overview, appearance, system
3. Graceful fallback to overview for any unrecognized page

### OMD/settings/pages/ QML types
- `qs.modules.settings.pages` exposes: OverviewPage, AppearancePage, SystemPage, KeyboardEditorOverlay
## Remaining (non-blocking / optional)

### QML Merge: sumika-modules/display/onScreenDisplay cleanup
- sumika-modules/display/onScreenDisplay/ has duplicate OSD QML files (leftover from before the official move to on-screen-display/). These could be cleaned up if unused.

### GUI Testing (requires Hyprland session)
- No smoke test possible without GPU/display session
- Enabled=false/true module loading behavior cannot be exercised headless
- omd-module-validate --all only checks manifest schema, not runtime loading

## Key Principles Verified

1. **Core allowlist enforced**: Only apps/omd-bar, apps/omd-polkit, apps/omd-settings, quickshell/core/**, quickshell/modules/{bar,common,settings,polkit}/**, quickshell/services/* (transitional), bin/infrastructure + thin shims, hypr/
2. **No business modules in OMD**: All 10 product-floor + 17 optional modules in $SUMIKA_MODULES_HOME
3. **Zero duplicate module IDs**: Between OMD and sumika-modules
4. **QML imports work**: notificationPopup, onScreenDisplay, overview types provided by sumika-modules with qmldir
5. **Settings pages module-driven**: ModuleLoader resolves first, Core fallback second
6. **omd-action dispatch**: All Hyprland bindings route through ActionManager
7. **Thin shims**: All bin/omd-* scripts delegate to share/bin/omarchy-* or module bins

## 仍留在 OMD 的 services 未来迁出条件

29 个 service singleton 当前以 **CORE (transitional)** 状态留在 OMD。以下条件全部满足时可逐步或批量迁出：

| # | 条件 | 说明 |
|---|------|------|
| 1 | ServiceManager 支持动态加载/卸载 singleton | 目前所有 service 是编译时 import 的单例。迁出需要按 module 级别的 lazy loading |
| 2 | 每个 service 有明确的外部模块 owner | 例如 Audio → sumika-modules/audio/, Network → sumika-modules/wifi/, etc. |
| 3 | 对应模块内的 QML UI 已全部外置 | 此项已满足（所有业务 UI 已在外置模块） |
| 4 | 无 Core 框架层直接 import service | 目前 ModuleLoader/ActionManager 等 Core 框架组件可能直接 import qs.services 某些类型 |
| 5 | 所有 consumer 改为通过 ServiceManager 桥接访问 | 当前部分 service 被直接 import qs.services.X 而不是走 ServiceManager |

### 禁止

- ❌ 在 OMD 新增直接 import qs.services.* 的业务 UI QML（已有 import 允许，不新增）
- ❌ 在 OMD 新增与现有 service 功能重复的实现
- ❌ 在 service 仍通过 ServiceManager 暴露前删除 OMD 中的 service 文件
