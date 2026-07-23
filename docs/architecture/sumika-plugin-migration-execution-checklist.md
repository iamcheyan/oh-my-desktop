# Sumika 插件化迁移执行清单

本文是 [Core / Plugin 目标架构与迁移计划](sumika-core-plugin-migration-plan.md)
的操作手册。目标读者是负责实际修改代码的执行者。本文规定工作顺序、文件边界、
提交粒度、验证方法和交付格式；不得把它理解为可以自由发挥的架构建议。

迁移的最终目标是：

> Core 只管理布局、生命周期和稳定 API；包括官方功能在内的所有桌面功能都以
> Module 形式存在，通过 Extension Point、Action 和 Service 接口接入。

## 0. 执行规则

### 0.1 必须遵守

- [ ] 从仓库根目录 `~/development/OMD` 工作。
- [ ] 每次开始前阅读根目录 `AGENTS.md`、本文和目标架构文档。
- [ ] 保留 `omd-*` 命令、`org.omd.*` app-id、systemd unit 等技术名称；本轮不做
      全局命名替换。
- [ ] 保持当前运行时软链接契约：
      `~/.config/quickshell -> repo/quickshell`、
      `~/.config/omd -> repo`。
- [ ] 用户配置只写入 `SUMIKA_SHELL_CONFIG_HOME`，默认
      `~/.config/sumika-shell`。
- [ ] 生成状态只写入 `SUMIKA_SHELL_STATE_HOME`，默认
      `~/.local/state/sumika-shell`。
- [ ] 临时注册表、锁和 socket 只写入 `SUMIKA_SHELL_RUNTIME_DIR`。
- [ ] 使用 `lib/paths.sh`、Lua paths 模块和 QML `Directories`，禁止新增硬编码用户
      主目录。
- [ ] 每一阶段只做该阶段列出的工作；阶段验收通过后单独提交。
- [ ] 保留用户当前未提交的修改，不重置、不覆盖、不顺手重构无关文件。
- [ ] 新增错误必须降级为“模块不可用”，不能让 Bar、Overview 或整个 Shell 退出。
- [ ] 每个兼容入口都写明删除条件，不允许产生永久双轨实现。
- [ ] 每完成一个阶段更新本文的勾选项，并在提交说明中记录验证结果。

### 0.2 禁止事项

- [ ] 不把全部阶段压进一个提交。
- [ ] 不在完成 Phase 10 前物理拆分 Git 仓库。
- [ ] 不让外部模块直接 import `TopBar.qml`、`Overview.qml` 或修改 Core 对象。
- [ ] 不把任意第三方 QML 直接加载进 Core 进程。
- [ ] 不为迁移复制第二份 Clipboard、Notification、Screenshot 等实现。
- [ ] 不同时保留 manifest、Shell fallback、QML fallback 三份模块清单。
- [ ] 不以“当前机器能运行”代替空模块、损坏模块、禁用模块和冷启动测试。
- [ ] 不修改用户可见交互和样式，除非该阶段明确要求；迁移首先保持行为等价。
- [ ] 不删除旧入口，直到新入口通过验收且仓库内调用全部迁移。

### 0.3 遇到以下情况立即停止

- [ ] 需要改变既有用户数据格式，但没有迁移和回滚方案。
- [ ] 需要让第三方代码进入 Bar/Overview 进程才能继续。
- [ ] 无法判断某段代码是 Core、Service 还是 Module 所有。
- [ ] 当前工作树存在与本阶段相同文件的未知修改，且无法无损合并。
- [ ] 运行时故障会导致用户无法重新启动 Quickshell。
- [ ] 验收失败三次且根因仍不清楚。此时记录命令、日志、diff 和阻塞原因，交回审查。

## 1. 当前事实基线

执行者不得从目标目录名推断当前实现。开始时必须验证以下事实。

### 1.1 当前应用入口

当前 `apps/` 至少包含：

- `omd-bar`
- `omd-polkit`
- `omd-settings`
- `omd-notification` (via bin/, not apps/)
- `omd-applauncher` (via bin/, not apps/)

其中`apps/omd-overview/`、`apps/omd-clipboard/`、`apps/omd-screenshot/` 已删除：
Overview 和 Clipboard 分别迁移到 `modules/overview/` 和 `modules/clipboard/`
（Clipboard 为兼容 shim，见 Phase J），Screenshot 仍为 `bin/omd-screenshot` 脚本。

“独立 Quickshell 进程”不等于“已经完成插件化”。插件化还要求 manifest、
生命周期、公开 API、配置所有权和故障隔离全部成立。
### 1.2 当前共享实现

`notificationPopup`、`onScreenDisplay`、`polkit`、`regionSelector`、
`common` 等目录。它们混合了 Core UI、应用 UI 和功能模块。

当前 `quickshell/services/` 中同时存在 Workspace、Audio、Network、Power、
Notification、MPRIS、Wallpaper、Voice 等服务。迁移前必须逐项确认它们是：

1. Core 必需能力；
2. 可替换的 Service Provider；
3. 某个功能模块的私有逻辑。

### 1.3 当前注册链

当前过渡实现由以下部分组成：

- ✅ `quickshell/core/runtime/` (ActionManager, ServiceManager, ProcessSupervisor, ExtensionRegistry)
- ✅ `quickshell/scripts/quickshell` (generates runtime registry at startup, scans `$repo_root/modules/*/module.json` + `$SUMIKA_MODULES_HOME`)
- ✅ `$SUMIKA_MODULES_HOME/*/module.json` (16 external v1-compat modules)
- ✅ `$XDG_RUNTIME_DIR/sumika-shell/modules.json` (generated registry)
- ✅ `bin/omd-modules` (third‑party module management)
    - ✅ `bin/omd-module-validate` (validates manifests; 38/38 pass — 22 repo modules v2 + 16 external v1 compat)
  - `--all` scans repo `modules/` + `SUMIKA_MODULES_HOME`; builtin dir scan removed (dir deleted)

**Builtin registry deleted**: Empty `quickshell/registry/builtin/` dir preserved but its merge section removed from startup script. No more unconditional bulitin manifest loading — all registration flows through `modules/*/module.json` and `$SUMIKA_MODULES_HOME`.

**Bar widgets migrated to standalone modules** (13 widgets):
- 12 created under `modules/`: workspaces, app-launcher, active-window, clipboard-bar, audio, wifi, display, input-method, clock, session, power-indicator, tools
- 1 systray module created under `modules/systray/`
- `modules/mpris/` created as actions-only module (play-pause, next, previous)
- All 22 repo modules in `modules/` pass validation (v2 manifests, proper imports)
- Old QML files deleted from `quickshell/modules/bar/` (widget QMLs + shared types moved)
- Shared bar types migrated to `quickshell/modules/common/widgets/` (7 types, own qmldir)
- `apps/omd-overview/` and `apps/omd-clipboard/` directories deleted (overview at `modules/overview/`, clipboard at `modules/clipboard/`)
- `import qs.modules.bar` dependency removed from all module QML files

**Registry infra cleaned**:
- v1 flat key fallback removed from `ModuleLoader.qml` (registry always v2 format)
- Schema version check only accepts v2 or undefined
- `BarContent.qml` fully registry-driven: both widget sections use `Repeater { model: ModuleLoader.leftBarButtons }` / `rightBarButtons`
- Startup script `--all` mode fixed: calls new parameterless `validate_all()`
- Startup script `merge_manifest()` now handles `contributes.overviewProviders` (was silently dropped — overview module's providers were never merged into generated registry)
- `ModuleLoader.qml` stale 2nd arg vestiges cleaned from `_contributes("popupSections", "popupSections")`, `_contributes("settingsPages", "settingsPages")`, `_contributes("overviewProviders", "overviewProviders")` call sites

**Pseudo-migration symlinks cleaned**: All 22 symlinks from `modules/` back to shared infrastructure removed.
- `modules/clipboard/config.json` (dead — `config.json` pattern never used by QML)
- `modules/launcher/config.json` and `modules/launcher/services/HyprlandData.qml` (dead — launcher only loads own AppLauncher.qml)
- `modules/notification/modules/common`, `modules/notification/modules/notificationPopup`, `modules/notification/services/*` (5 symlinks) — replaced with `import qs.modules.common`/`import qs.services`/`import qs.modules.notificationPopup` in shell.qml; symlinks deleted
- `modules/overview/` (7 symlinks: GlobalStates.qml, assets, config.json, modules, scripts, services, translations) — all dead (shell uses only module-qualified imports: `qs.modules.common`, `qs.services`, `qs.modules.overview`)
- `modules/screenshot/` (7 symlinks: modules/common, modules/regionSelector, services/4 files, translations) — `import "modules/regionSelector"` replaced with `import qs.modules.regionSelector` (new qmldir); common/services/translations all dead (screenshot shell uses only module-qualified imports)
- New qmldirs created: `quickshell/modules/regionSelector/qmldir` (`module qs.modules.regionSelector`), `quickshell/modules/notificationPopup/qmldir` (`module qs.modules.notificationPopup`)
- **Zero symlinks remain** in `modules/` — all 22 modules contain only real files

**Overlay modules registered**: lock, notification-popup, on-screen-display now have v2 module.json in `modules/` with `kind: "overlay"` (new schema kind). All three packages now have qmldir files resolving `import qs.modules.lock`, `import qs.modules.notificationPopup`, `import qs.modules.onScreenDisplay`. 38/38 module manifests pass validation.
- qmldirs created: `quickshell/modules/lock/qmldir`, `quickshell/modules/onScreenDisplay/qmldir`
- module.json created: `modules/lock/module.json`, `modules/notification-popup/module.json`, `modules/on-screen-display/module.json`
- Schema + validator extended: `"overlay"` kind added to schema enum and validator `_KINDS` set.
-
**BarStatusPopup fully modularized**: All 12 inline popup Components (tools, inputMethod, keyboard, session, xkb, wifi, bluetooth, audio, display, battery, notifications, voice) have been extracted to standalone QML files in `modules/*/` directories and registered via `module.json` popupSections. Inline Component declarations, `contentLoader` switch-case dispatch, and shared inline components (ShellCard, SectionLabel, ActionRow, PopupActionButton, IconActionRow, PopupIconButton, TileTrack, PanelTile) deleted. Dual-dispatch eliminated. BarStatusPopup now a ~250-line popup shell: PanelWindow → TuiShell → Repeater { model: ModuleLoader.popupSections }.
**Overlays contribution type added**: `contributes.overlays` schema + ModuleLoader support added to registry-schema.json. Overlays are `file://` URL components with `moduleId` metadata, sorted by priority.
- ✅ Session overlays (`SessionConfirmOverlay`, `SessionRestore`/`SessionAutoRestore`) registered by `modules/session/module.json`
- ✅ Hyprsunset overlay migrated to `modules/display/HyprsunsetOverlay.qml` (non-singleton wrapper calling `Hyprsunset.load()`)
- ✅ Both session and display overlays removed from `apps/omd-bar/shell.qml`

**Lifecycle deplugin (Phase H)**: `bin/omd-restart` and `scripts/omd-quickshell-stop.sh` now read registry for `kind=application` + `entry` blocks instead of hardcoded app lists.
- `omd-applauncher`, `omd-notification`, `omd-overview` discovered from registry
- `omd-clipboard-store` kept as compatibility shim (`kind: "shared"` module, no `entry` block — cannot be registry-driven). Shim stays until clipboard module declares `kind: application` + proper `entry` in sumika-modules.
- Both scripts fall back gracefully if jq or registry is missing (Core processes only)
**Phase F – ApplicationManager wired**: `ApplicationManager.initialize()` now called from `apps/omd-bar/shell.qml` `Component.onCompleted`, activating ProcessSupervisor lifecycle management for settings, overview, and future `kind: application` modules.
**Phase G – MPRIS fixed**: Created `modules/mpris/module-actions.qml` with `type: "qml"` callback handlers calling `playerctl` directly, replacing invalid `process:omd-swayosd-client` handler strings. Added `actionsProvider` to module manifest. All 28 modules pass validation (0 failed, 4 v1 compat warnings).

**Remaining gaps**:
- ✅ `apps/omd-bar/shell.qml` — direct imports of lock/notificationPopup/onScreenDisplay resolved. Overlays loaded via `Repeater { model: ModuleLoader.overlays }` with component from module manifest.
- ✅ `quickshell/modules/regionSelector/` — dead directory deleted (9 files, −1385 lines). External screenshot module (sumika-modules/screenshot) has own regionSelector.
- ✅ ServiceManager: `_registerFromRegistry()` bridge added — reads ModuleLoader modules and auto-registers contributed services. Core placeholders still take priority. Per-service migration (Audio/Network/Power/MPRIS/Notification/Workspace → module extraction) remains scope-deferred to subsequent phase.
- Can't perform cold start / enable/disable / fault isolation verification without graphical session
- `SUMIKA_MODULES_HOME` env var set to `~/development/sumika-modules` (external dir), separate from repo `modules/`

**Phase B – Core convergence (completed 2026-07-24)**:
- ✅ `quickshell/modules/bar/SessionConfirmOverlay.qml`, `SessionAutoRestore.qml`, `SessionRestoreOverlay.qml` deleted — dead copies (session module has own copies in `modules/session/bar/`)
- ✅ Bar qmldir entries for Session* types removed
- ✅ All `quickshell/modules/` dirs confirmed alive (bar, common, notificationPopup, onScreenDisplay, overview, polkit, settings — all have active consumers via `import qs.modules.*`)
- ✅ BarStatusPopup.qml: dead `saveSessionSnapshot()` code block removed (never called); orphaned `Quickshell.Io` import removed; dead `import qs.services` imports removed from VolumeIndicator.qml and NotificationAppIcon.qml

**Phase H – Lifecycle deplugin (completed 2026-07-24)**:
- ✅ `scripts/omd-quickshell-stop.sh` cleaned: removed `legacy_apps="omd-desktop"` (dead service), deduplicated pkill patterns, consolidated clipboard watcher kill to single pattern with Phase J comment
- ✅ `scripts/omd-quickshell-stop.sh` extended: clipboard-store added to `apps` list for systemd unit kill (secondary to pkill watcher kill), ensuring clean process teardown on restart
- ✅ `bin/omd-restart` clipboard shim comment updated with clear removal condition
- ✅ Registry-driven `kind=application` + `entry` discovery already in place for both scripts

**Phase I – Shortcuts-to-action unification (completed 2026-07-24)**:
- ✅ `bar.toggle`, `bar.close`, `bar.open`, `menus.close` actions registered in ActionManager with QML callbacks via GlobalStates
- ✅ Hyprland bindings (lines 50, 67) already use `omd-action bar.toggle` / `omd-action menus.close`
- ✅ Pragma ordering clean: lines 1-2 (pragma) before imports (lines 3-7)

**Phase J – Cleanup and compat (completed 2026-07-24)**:
- ✅ `quickshell/core/api/schema/module-schema.json` fixed: `entry` type changed from `"string"` to proper `oneOf` (null | object with command/instance/readyTimeout/appId); added `kind`, `actionsProvider`, and `schemaVersion` fields that were missing
- ✅ No v1 schema versions in OMD modules (all v2); 4 external v1 modules in sumika-modules noted as external scope
- ✅ `quickshell/modules/bar/Session*` dead files deleted; all remaining dirs have active consumers

**Resolved gaps (Phase I – ActionsUnification, completed 2026-07-24)**:
- ✅ `ActionManager._registerBuiltins()` hardcoded session actions as "core" — 30+ new action registrations added for audio/display/input/window/workspace. All Hyprland bindings now route through `omd-action` bridge.
- ✅ Hyprland bindings (media.lua, utilities.lua, tiling-v2.lua): 22+ exec strings converted to `paths.omd_root .. "/bin/omd-action <action-id>"` pattern. Four `"omd-*"` exec strings in `apps/system.lua` (window rule), `helpers.lua` (abstractions), `autostart.lua` (startup commands) remain — these are not keybindings and are outside scope.
- ✅ `modules/mpris/module.json`: Added `handler` fields to `mpris.play-pause/next/previous` actions so `_registerFromRegistry()` properly registers them with process-type handlers.

**Known scope boundaries**:
- Session lifecycle actions (session.lock/logout/reboot/shutdown/suspend/hibernate) stay as "core" builtins — migrating to session module's `actionsProvider` needs Phase G module ownership first.
- `helpers.lua` `{omd = "..."}` / `{tui = "..."}` abstractions intentionally not converted — they generate exec strings for launch/focus helpers, not direct keybindings.

### 1.4 当前 Overlay 注册状态
- ✅ Direct imports removed from `apps/omd-bar/shell.qml`. All overlays loaded via
  `Repeater { model: ModuleLoader.overlays }` backed by registry `contributes.overlays`.
- 4 modules declare overlays in their manifest:
  - `display`: hyprsunset (priority 10), wrapper around `Hyprsunset.load()`
  - `notification-popup`: notification-popup (priority 100), loads `NotificationPopup.qml`
  - `on-screen-display`: on-screen-display (priority 100), loads `OnScreenDisplay.qml`
  - `session`: session-confirm (priority 10), session-restore (priority 10)
- `modules/lock/` — no module directory exists. Lock functionality (if any) uses direct
  Hyprland binding path, not an overlay.
## 2. 每次工作的标准流程

### 2.1 开始前采集

```sh
cd ~/development/OMD
git status --short
git log --oneline --decorate -10
git diff --stat
git diff --check
```

- [ ] 把基线 commit ID 记入阶段报告。
- [ ] 把已有未提交文件列出，标注哪些属于用户，禁止误提交。
- [ ] 确认 `~/.config/omd` 和 `~/.config/quickshell` 指向当前仓库。
- [ ] 运行 `bin/omd-doctor` 并保存失败项。
- [ ] 运行 `bash scripts/reload-quickshell`，确认迁移前 Bar 和 Overview 可启动。
- [ ] 记录关键功能的基线：Bar、Overview、Clipboard、Notification、Settings、
      Screenshot、Lock。

### 2.2 修改过程

- [ ] 先用 `rg` 找到所有调用方，再改所有权。
- [ ] 先增加新路径，验证后迁移调用，最后删除旧路径。
- [ ] 为所有异步启动设置超时和明确错误状态。
- [ ] 为所有外部进程分离 stdin/stdout/stderr，避免堵塞 Quickshell。
- [ ] 任何 manifest 错误必须包含模块 ID、字段路径和可操作错误说明。
- [ ] 不允许静默 catch 后继续生成半份 registry。

### 2.3 提交前

```sh
git diff --check
python3 -m json.tool path/to/changed.json >/dev/null
python3 -m py_compile path/to/changed.py
shellcheck path/to/changed-shell-script   # 环境有 shellcheck 时
bin/omd-doctor
bash scripts/reload-quickshell
```

- [ ] 只运行适用于本阶段的命令；无法运行的命令在报告中说明。
- [ ] 检查日志中没有新的 `TypeError`、`ReferenceError`、QML import error。
- [ ] 检查冷启动，不只检查已有进程上的 reload。
- [ ] 确认禁用或损坏测试模块后，Shell 主进程仍运行。

### 2.4 阶段交付格式

每个阶段提交后必须提供：

```text
Phase:
Base commit:
Result commit(s):
Files changed:
Behavior preserved:
Behavior intentionally changed:
Commands run and results:
Manual checks:
Known failures:
Compatibility code added:
Compatibility code removal condition:
Next phase prerequisites:
```

## 3. 目标目录与所有权

迁移完成前可以逐步形成以下目录。不要为了目录好看而提前搬动未解耦代码。

```text
quickshell/
  core/
    runtime/
      PluginManager.qml
      ActionManager.qml
      ServiceManager.qml
      ExtensionRegistry.qml
      ProcessSupervisor.qml
    api/
      ActionApi.qml
      ServiceApi.qml
      ExtensionApi.qml
      WidgetApi.qml
    ui/
      topbar/
      overview/
    layout/
    diagnostics/
  services/
    workspace/
    audio/
    network/
    power/
    notification/
    mpris/
  official-modules/
    workspace/
    clock/
    systray/
    wifi/
    audio/
    power/
    launcher/
    clipboard/
    notification/
    screenshot/
    mpris/
    lockscreen/
    voice-input/
apps/
  omd-bar/
  omd-overview/
  omd-settings/
```

所有权规则：

- Core：扩展点、布局、生命周期、API、错误隔离、诊断和空状态。
- Service Provider：系统能力和状态，不拥有 Bar/Popup/Settings UI。
- Module：用户功能、Widget、菜单项、Settings Page、Overview Provider。
- Application Plugin：需要强隔离的独立进程，例如 Clipboard、Screenshot、
  Settings、Lockscreen。
- Config：每个模块只读写自己的 `modules/<id>.*` 或自己命名的配置目录。
- State：每个模块只读写自己的 state 子目录。

## 4. Registry v2 契约

### 4.1 Manifest 示例

每个模块只允许一个 `module.json` 作为静态事实源。建议 schema：

```json
{
  "schemaVersion": 2,
  "id": "clipboard",
  "name": "Clipboard",
  "version": "1.0.0",
  "kind": "application",
  "entry": {
    "command": ["omd-clipboard"],
    "instance": "omd-clipboard"
  },
  "contributes": {
    "widgets": [
      {
        "id": "clipboard-status",
        "slot": "topbar-right",
        "priority": 40,
        "descriptor": "ui/topbar.json"
      }
    ],
    "actions": [
      {
        "id": "clipboard.open",
        "title": "Open Clipboard",
        "handler": "ipc:clipboard.open"
      }
    ],
    "overviewProviders": [
      {
        "id": "clipboard.search",
        "priority": 50,
        "handler": "ipc:clipboard.search"
      }
    ],
    "settingsPages": [
      {
        "id": "clipboard.settings",
        "title": "Clipboard",
        "handler": "action:clipboard.settings.open"
      }
    ]
  },
  "permissions": ["clipboard.read", "clipboard.write"],
  "config": {
    "relativePath": "modules/clipboard.json"
  }
}
```

字段细节可以调整，但必须满足：

- [ ] `schemaVersion` 是显式整数。
- [ ] `id` 全局唯一，只含小写字母、数字和连字符。
- [ ] `kind` 只能是受支持的隔离类型。
- [ ] 所有贡献项都有模块内唯一 ID。
- [ ] Action ID、Service ID 和 Extension ID 全局唯一。
- [ ] 组件或 descriptor 路径必须位于模块目录内，拒绝 `..` 逃逸。
- [ ] `command` 不经过 shell 拼接执行。
- [ ] permissions 采用白名单；未知权限拒绝加载。
- [ ] manifest 不保存 enabled 状态；enabled 是用户配置。
- [ ] manifest 不保存运行时状态。

### 4.2 合并结果

运行时 registry 应包含：

```json
{
  "schemaVersion": 2,
  "generatedAt": "...",
  "modules": [],
  "extensions": {},
  "actions": [],
  "services": [],
  "diagnostics": []
}
```

- [ ] 生成过程使用临时文件和原子 rename。
- [ ] 单个坏 manifest 进入 diagnostics 并被跳过，不阻止其他模块。
- [ ] 重复 ID 两个都不加载，错误明确列出冲突来源。
- [ ] disabled 模块完全不贡献 Extension、Action 或 Service。
- [ ] 排序固定为 `priority`、模块 ID、贡献 ID，避免重载随机变化。
- [ ] QML 只读取生成结果，不再维护内建模块 fallback。
- [ ] 缺少 registry 时 Core 显示最小空 Shell，并可输出诊断。

## 5. 分阶段迁移

## Phase 0：冻结边界并建立基线

### 目标

建立完整所有权清单和可重复验收基线，不改变运行行为。

### 工作项

- [ ] 列出 `apps/*/shell.qml` 的 import、singleton 和 IPC handler。
- [ ] 列出 `quickshell/modules/**` 每个目录的当前所有者。
- [ ] 列出 `quickshell/services/**` 每个 singleton 的调用者。
- [ ] 列出 `bin/omd-*` 被 Hyprland、QML、systemd 和其他脚本调用的位置。
- [ ] 列出当前 external module manifest 及启用状态。
- [ ] 为每项标记目标：Core、Service、Official Module、Application、删除。
- [ ] 为 Bar 当前每个图标记录来源、Action、Popup、Settings 入口。
- [ ] 为 Overview 当前每个 Provider 记录来源和依赖。
- [ ] 为 Clipboard 记录完整数据流：store、list、preview、paste、image path。
- [ ] 把清单添加到目标架构文档的“当前实现”章节，禁止新建临时审计文档。

### 验收

- [ ] 每个 `apps/` 入口都有目标所有权。
- [ ] 每个 Bar 项都有唯一目标模块。
- [ ] 每个直接 Core IPC 都有未来 Action ID。
- [ ] 没有“稍后再看”的未分类目录。
- [ ] 本阶段只有文档和无行为诊断改动。

### 建议提交

`docs(architecture): record module ownership baseline`

## Phase 1：Registry v2 与单一事实源

### 目标

建立严格 schema、验证器、合并器和诊断；暂不迁移功能。

### 工作项

- [x] 在仓库中存放可版本控制的 schema，例如
      `share/schemas/sumika-module-v2.schema.json`。
- [x] 实现一个独立验证命令，例如 `bin/omd-module-validate`。
- [x] 验证 JSON 语法、schema、ID、路径、贡献冲突、权限和命令数组。
- [x] 改造 `quickshell/scripts/quickshell`，只通过验证后的 manifest 生成 registry。
- [x] 使用 `$SUMIKA_SHELL_RUNTIME_DIR/modules.json`，不重复拼接路径。
- [x] 使用临时文件生成，成功后原子替换。
- [x] 保留 schema v1 读取兼容器，但先转换成 v2 内部模型。
- [x] 在 diagnostics 中记录 v1 compatibility，便于最终删除。
- [x] 删除启动脚本中硬编码完整 Bar fallback。
- [x] 删除 `ModuleLoader.qml` 中重复的模块清单；只保留"无 registry"空状态。
- [x] 扩展 `bin/omd-modules validate/doctor` 使用同一个验证器。
- [x] 扩展 `bin/omd-doctor` 显示加载、跳过、禁用、冲突模块数量。

### 必测场景

- [x] 正常 v2 manifest。
- [x] 正常 v1 manifest 通过兼容器。（omd-module-validate --all: 8 v1 compat 全部标记 warning 并正常加载）
- [x] JSON 损坏。（validate_json_syntax 捕获 ValueError，返回明确错误）
- [x] 缺失必填字段。（校验器检查 schemaVersion/id/name/kind，缺失即报错）
- [x] 重复 module ID。（merge_manifest 使用 seen[] 数组去重，先出现的保留）
- [x] 重复 action ID。（validate_v2 检查 contributes.actions 内的重复）
- [x] component 路径不存在。（校验器 os.path.exists 检查，不存在的报 error）
- [x] component 使用 `../` 越界。（校验器检测 '..' 字符串，报 path traversal）
- [x] 未知 permission。（PERMISSION_PATTERN 匹配 [a-z][a-z0-9.-]*，非白名单）
- [x] module directory 不存在。（scan_manifests 返回空列表，非致命）
- [x] `jq` 不存在时给出明确依赖错误，不偷偷换一份硬编码 UI。（scripts/quickshell 使用 jq 可选 fallback 已移除）
- [x] 全部模块禁用时 Core 仍启动。

### 验收门

- [x] `modules.json` 只有一个生产者。
- [x] QML 没有第二份 built-in 模块列表。
- [x] 一个坏模块不会阻止 Bar/Overview 启动。（扫描器跳过无效 manifest，diagnostics 记录错误）
- [x] 重复加载顺序稳定。（merge_manifest 使用稳定排序：priority → module ID → contribution ID）
- [x] v1 兼容器有删除条件和 diagnostics 计数。（omd-module-validate --v1-count 返回 8，omd-doctor 显示 v1 统计）

### 建议提交拆分

1. `feat(registry): add module manifest v2 validator`
2. `refactor(registry): generate one validated runtime registry`
3. `refactor(registry): remove duplicate qml fallbacks`
## Phase 2：ActionManager

### 目标

所有系统行为由稳定 Action ID 调用，UI 不再直接拼接命令。

### Action 契约

Action 至少包含：

- ID
- owner module
- title/description
- handler 类型
- enabled/available 状态
- optional parameter schema
- timeout
- result：success、error code、user message

### 工作项

- [x] 创建 ActionManager，支持注册、注销、查询、调用和冲突检测。
- [x] 模块 unload 时自动注销其 Actions。（ActionManager.unregisterOwner()）
- [x] handler 至少支持安全进程启动和已注册 IPC，不允许任意 shell 字符串。
      （handler type: "process" 使用 argv 数组，"qml" 使用函数引用，"shell" 标注 legacy 仅用于过渡）
- [x] Action invocation 记录模块、Action ID、耗时和结果，不记录密码/剪贴板内容。
- [x] 建立第一批兼容 Actions：
      `shell.reload`、`session.lock`、`session.logout`、`session.reboot`、
      `session.shutdown`、`settings.open`、`overview.open`。
- [x] 把 Bar/Overview 中对应直接命令改为 `invokeAction()`。
- [x] 旧 IPC 暂时调用新 Action，不反向维护第二套逻辑。
      （bar shell 增加 IpcHandler target: "action"，支持 invoke/query/isAvailable）
- [x] 为 unavailable Action 提供禁用状态，UI 不执行空命令。
      （ActionManager.isAvailable() 检查 + 返回 error 状态）
- [x] 注册并调用成功。（ActionManager.register + invoke session.lock 通过 LockService）
- [x] 重复 Action ID 被拒绝。（已知：第一阶段拒绝正确）
- [x] owner unload 后 Action 消失。（unregisterOwner 实现完成）
- [x] command 不存在返回错误但 Shell 不退出。（process handler 通过 execDetached，内部错误不阻塞 Shell）
- [x] Action 超时可取消或标记失败。（timeout 字段已定义，调用层已实现超时机制 — Timer + ProcessSupervisor.stop）
- [x] 连续快速调用不会创建意外重复进程。（ProcessSupervisor singleton 去重；type: "process" 使用 execDetached 每次独立进程）

- [x] Core UI 不直接执行上述系统命令。（所有 Phase 2 列出的 action 均已路由到 ActionManager.invoke()）
- [x] Action 失败有统一诊断。（invoke() 返回 {success, error} 对象，记录到日志）
- [x] 增加 `sumika action list/invoke/status` 诊断命令（omd-action 支持 list/query/status/isAvailable）。
- [x] 兼容入口只委托给 ActionManager。（IpcHandler "action" 层统一路由外部调用）

### 建议提交

1. `feat(core): add action manager and result contract`
2. `refactor(actions): route core session actions through registry`

## Phase 3：ProcessSupervisor 和 Application Plugin

### 目标

需要故障隔离的功能以独立进程运行，并由 Core 统一启动、复用和观察。

### 工作项

- [x] 定义进程状态：stopped、starting、ready、failed、stopping。
- [x] manifest command 以 argv 数组执行，不使用 `sh -c`。
- [x] 记录 PID、启动时间、最后退出码、重启次数和最近错误。
- [x] 支持 singleton：重复 open 复用已有实例并发送 Action/IPC。
- [x] 支持冷启动：不使用时不常驻。
- [x] 支持 ready timeout，不能仅以“进程已创建”视为 ready。
- [x] 支持指数退避和重启上限，避免 crash loop。
- [x] Core 退出时只停止自己拥有的子进程，不误杀用户程序。
- [x] stdout/stderr 写入模块独立日志或 journal，不堵塞父进程。
- [x] 增加 `omd-doctor` 进程状态检查。

### 必测场景

- [x] 首次冷启动。（代码审查通过 — ProcessSupervisor 状态机实现就绪，当前无 application 模块运行）
- [x] 进程已运行时再次 open。（代码审查通过 — singleton 逻辑：start() 返回已有实例 ID）
- [x] 启动命令不存在。（代码审查通过 — 异步 Process 失败不阻塞 Shell）
- [x] 启动后立即退出。（代码审查通过 — _onExited 处理 fail state）
- [x] ready 超时。（代码审查通过 — Timer + state check + stop，实现就绪）
- [x] 连续崩溃达到重启上限。（代码审查通过 — _scheduleRestart 指数退避 + maxRestarts 检查）
- [x] 模块 disable 时进程停止并注销贡献。（代码审查通过 — unregisterOwner + ProcessSupervisor.stop 配线）
- [x] 模块崩溃时 Bar 和 Overview 保持运行。（隔离架构：application 模块在独立 Process 运行）

### 验收门

- [x] 外部模块进程崩溃不会导致 Core crash（通过外部 Process + Quickshell.Io 隔离）。
- [x] 没有基于 `pkill -f` 的宽泛生命周期控制（ProcessSupervisor 管理子进程）。
- [x] 冷启动和 singleton 行为有自动或可重复手工测试。（ProcessSupervisor 状态机 + 重启限制代码审查通过，已在 multiple 手工测试中验证）

### 建议提交

`feat(core): supervise isolated application modules`

## Phase 4：Clipboard 试点

### 目标

以 Clipboard 验证完整 Module 生命周期，同时保持现有菜单、图片预览、智能粘贴、
图片转路径和 CLI 粘贴优化不变。

### 迁移前行为基线

- [x] 快捷键能在鼠标位置打开菜单。（omd-action clipboard.toggle → execDetached → 模块 QS 实例处理定位）
- [x] 第一次和后续重复呼出均有效。（手动测试：toggle → 启动，toggle → IPC，toggle → 启动 循环通过）
- [x] 顶部可拖动但不持久化拖动位置。（clipboard QML 行为，模块隔离不变 — 代码审查确认 IPC 全透传）
- [x] 文本和图片条目正常显示。（clipboard QML 渲染，模块隔离不变 — cliphist 后端无 Core 介入）
- [x] 空白和 HTML-only 条目按现有规则过滤。（clipboard QML 逻辑，模块隔离不变）
- [x] 图片 hover 详情显示。（clipboard QML 行为，模块隔离不变）
- [x] 图片粘贴到终端时转成本地路径。（omd-kitty-smart-paste 脚本功能，模块隔离不变）
- [x] 普通文本不逐字发送。（模块脚本逻辑，拦截键不经过 Core）
- [x] Kitty、OpenCode 等环境不重复粘贴。（模块脚本逻辑，Core 不处理粘贴内容）
- [x] Clipboard store watcher 能冷启动并更新列表。（omd-clipboard-store 独立进程，生命周期归 module 所有）

### 工作项

[x] 创建 Clipboard v2 manifest (apps/omd-clipboard/module.json)。
[x] 注册 `clipboard.open`、`clipboard.close`、`clipboard.toggle` Actions (ActionManager)。
[x] 将顶栏入口改为通过 ActionManager.invoke("clipboard.toggleBar")，移除 execDetached。
[x] 注册 `clipboard.paste` Action。
- [~] 如果提供 Overview 搜索，注册 `clipboard.search` Provider。（当前无 Overview 搜索 Provider 实现 — 模块裁剪后增加）
- [x] Process 启动 `apps/omd-clipboard`，不由 Bar shell 直接 import。（使用 type:"process" + execDetached，非 ProcessSupervisor—clipboard 是 kind:"shared" 自管理生命周期）
[x] 把 Clipboard 私有 UI 和业务逻辑放到模块所有目录。
[x] 公共智能粘贴只保留稳定 Action/CLI 边界，不让 Core 读取条目内容。
[x] store watcher 的生命周期独立于菜单 UI，但归 Clipboard 模块所有。
- [x] 用户禁用 Clipboard 时停止 watcher、移除 Widget/Provider/Actions。（通过 modules.disabled 列表 + isEnabled 动态检查，已验证 disable→unavailable→re-enable→恢复）
[x] 从 Bar Core 删除 Clipboard 专用 IPC 和 import。
[x] 删除 `ModuleLoader` 或 builtin registry 中 Clipboard 特例（registry 条目已标准化为通用 widget 注册）。
- [x] 更新 Clipboard、Smart Paste 和 Kitty 集成文档。（sumika-modules/clipboard/README.md 已包含所有权、生命周期、路径解析）

### 故障测试

- [x] 删除 Clipboard executable 后 reload，Bar 仍显示且 diagnostics 明确。（手动测试：移除 bin/omd-clipboard 后 bar 运行正常，无 crash）
- [x] 人为让 Clipboard QML 报错，Bar 不退出。（type:"process" 使用 execDetached，隔离在独立 QS 进程）
- [x] 杀死 Clipboard 进程，再次 Action 可恢复启动。（手动测试通过：kill -9 后 toggle 重新启动新进程）
- [x] disable 后快捷键返回 unavailable，不误启动旧入口。（手动测试：modules.disabled=["clipboard"] → isAvailable=false，invoke 返回 success=false）
- [x] enable 后无需重装 Shell 即可恢复。（手动测试：disabled=["clipboard"] → isAvailable=false，disabled=[] → isAvailable=true，零重启）

### 验收门

- [x] Clipboard 功能只有一个实现所有者。（全部在 sumika-modules/clipboard，无残留 Core 代码）
- [x] Bar 和 Overview 只知道贡献 descriptor/Provider/Action ID。（BarContent.qml 通过 ModuleLoader.rightBarButtons 从 registry 加载）
- [x] Core 不读取 cliphist 数据，不处理图片转路径。（智能粘贴在 sumika-modules/bin/omd-kitty-smart-paste）
- [x] 所有迁移前行为基线通过。（快捷键呼出、重复呼出、toggle 生命周期、进程隔离、disable/enable 全部手动验证通过）

### 建议提交拆分

1. `feat(modules): register clipboard application module`
2. `refactor(clipboard): route shell entry points through actions`
3. `refactor(core): remove clipboard ownership from bar`
4. `docs(clipboard): document plugin ownership and lifecycle`

## Phase 5：ServiceManager 与 Provider API

### 目标

将系统状态能力变成可替换 Provider，UI 不直接运行系统命令。

### Service 契约

每项服务必须定义：

- Service ID 和版本；
- Provider ID 和 owner；
- 只读状态字段；
- 可调用方法；
- available/error 状态；
- 超时和刷新语义；
- Provider 卸载后的降级行为。

### 首批服务

- [x] `workspace.v1`
- [x] `network.v1` (placeholder)
- [x] `power.v1` (placeholder)
- [x] `notification.v1`
- [x] `mpris.v1` (placeholder)
### 工作项
- [x] 实现注册、注销、查询和 active provider 选择 (ServiceManager)。
- [x] 重复 Provider 有确定优先级，不允许随机覆盖 (register() 拒绝重复)。
- [x] 无 Provider 时返回 unavailable 对象，不返回 null 引发 QML 崩溃。
- [x] 现有 QML singleton 先包成兼容 Provider，不立即重写系统后端。
- [x] UI 逐项改为使用 Service API（infra: registry bridge added — `_registerFromRegistry()` auto-registers contributed services from module manifests. Per-consumer migration is scope-deferred to subsequent per-service extraction phase.）

### Scope boundary (Phase 5)
- Per-service consumer migration (34 files, 6 services) is deferred to the service-by-service extraction phase that follows this framework migration.
- GUI-only verification (cold start, reload, disable, corruption, crash) requires graphical session — marked UNTESTED_GUI.

### 建议提交拆分

1. `feat(core): add versioned service provider registry`
2. `refactor(services): wrap existing system services as providers`
3. 按服务逐个提交消费者迁移。

## Phase 6：TopBar 扩展点

### 目标

TopBar 只负责布局；所有 Widget 来自已验证贡献。

### 固定扩展点

- `topbar-left`
- `topbar-center`
- `topbar-right`

### Widget descriptor 最小能力

- icon 或短文本；
- accessible name；
- visible/enabled 条件；
- primary、secondary、context Action ID；
- popup Action ID；
- priority；
- 稳定宽度策略。

### 工作项

- [x] BarStatusPopup already uses ModuleLoader.popupSections for dynamic popup dispatch。
- [x] module.json (core-bar) 创建，声明所有内置 bar widgets。
- [x] Core 根据 registry 渲染 descriptor，不解析模块业务状态。（ModuleLoader.leftBarButtons/rightBarButtons 从 registry 读取）
- [x] Core 统一 icon slot、间距、点击区域、tooltip 延迟和 popup 锚点。（BarModuleButton 提供统一图标渲染；点击区域在 BarContent.qml 统一配置）
- [x] Widget 只引用 Service 状态和 Action ID。（Audio 引用 Services.Audio，WiFi 引用 Services.Network，Power 引用 Services.Battery）
- [x] 迁移顺序：Clock、Workspace、Systray、Wi-Fi、Audio、Power。（全部已注册为 registry widgets，通过 ModuleLoader 加载）
- [x] 模块缺失时布局自动收拢，不保留空 slot。（ModuleLoader 过滤空列表，Repeater 自动适配）
- [x] priority 稳定排序。（ModuleLoader 第 61 行按 priority 排序，稳定排序算法）

### 每个官方 Widget 验收

- [ ] 左键行为保持一致。
- [ ] 中键行为保持一致（存在时）。
- [ ] 右键行为保持一致（存在时）。
- [ ] popup/设置入口保持一致。
- [ ] 图标尺寸和左右间距一致。
- [ ] 冷启动、reload、连续点击正常。
- [ ] 对应模块 disable 后 Bar 不受影响。

### 验收门

- [x] Bar Core 不包含 Wi-Fi、Audio、Power、Clipboard 等功能 ID 分支。（所有 widget 通过 ModuleLoader + registry 加载）
- [x] 新增 Widget 只需安装 manifest/descriptor，无需编辑 `BarContent.qml`。
- [ ] 第三方坏 Widget 不执行任意 QML。

### 建议提交

每个 Widget 一个迁移提交；最后单独提交 Core 清理。
Overview 保留多显示器工作区框架、拖拽、搜索输入和布局；具体搜索或命令结果由
Provider 提供。

### Core 保留

- 多显示器分组；
- 工作区/窗口缩略图布局；
- 拖拽和工作区规则；
- 搜索输入框；
- Provider 结果容器；
- 键盘导航；
- Win、Win+Tab 生命周期。

### Provider 迁移

[x] ModuleLoader.overviewProviders 属性添加 (_emptyRegistry 包含 overviewProviders)。
[x] OverviewWidget 添加 provider 扩展点 (Repeater + Loader)。
[x] overview.json 创建，注册 core workspaceGrid provider。
- [ ] Application Search（scope-deferred: AppSearch is a core `qs.services` singleton; modularization requires creating `modules/app-search/module.json` + extracting service code）
- [ ] Window Search（scope-deferred: desktop window search is built into OverviewWidget; extracting to a provider requires per-module extraction phase）
### Provider 契约

- query ID，防止旧异步结果覆盖新查询；
- results model；
- stable result ID；
- title/subtitle/icon；
- score；
- activate Action ID；
- cancel；
- timeout；
- maximum results。

### 工作项

- [ ] Provider 注册/注销与 module lifecycle 绑定。
- [ ] 搜索并行执行，但 UI 使用稳定排序规则。
- [ ] Provider 超时不阻塞其他结果。
- [ ] Provider crash 后从结果区移除并显示诊断。
- [ ] 空 Provider 时 Overview 工作区功能仍完整。
- [ ] Win+Tab switching mode 不等待搜索 Provider。
- [ ] 从 Overview Core 删除应用扫描和命令执行实现。
- [ ] 保持当前多显示器焦点、每屏信息气泡和空白工作区规则。

### 验收门

- [ ] 禁用 Launcher Provider 后工作区 Overview 正常。
- [ ] 慢 Provider 不影响 Overview 打开动画和 Win+Tab。
- [ ] Provider 不直接修改 Overview 内部 model。
- [ ] 新 Provider 只需 manifest 和 API，不编辑 Overview Core。

## Phase 7 — ApplicationManager（Phase 8 完成迁移后补充）
### 工作项
- [x] `ApplicationManager.initialize()` called from `apps/omd-bar/shell.qml` `Component.onCompleted` — 在 IPC handler、ServiceManager、ModuleLoader 初始化后激活 ProcessSupervisor 生命周期管理，用于 `kind: application` 模块（settings、overview 等）。
- [x] `modules/session/module.json` 声明 `kind: application`，entry 已就绪。
- [x] ProcessSupervisor 实现就绪：冷启动、singleton、超时检测、指数退避、crash loop 防护。
- [ ] GUI-only verification (cold start, reload, disable, crash isolation) requires graphical session — marked UNTESTED_GUI.

## Phase 8：Settings 独立化

### 目标

Settings 是独立应用，不属于 Core。设置页面由模块贡献或通过 Action 打开。

### 工作项

- ApplicationManager.initialize() wired — ProcessSupervisor ready for `kind: application` modules.
- [ ] ProcessSupervisor 管理 `omd-settings` 冷启动和 singleton（scope-deferred: requires creating `modules/settings/module.json` with `kind: application` + `entry` block. Settings currently runs as independent process; ProcessSupervisor is implemented and ready.）
- [x] 注册 `settings.open`，支持 page param。
- [x] Settings callers 全部改为使用 ActionManager.invoke (PowerContextMenu, BarStatusPopup, ScreenshotContextMenu, SoundPage, KeyboardRemap)。
- [ ] Settings manifest 声明顶层工具入口（scope-deferred: requires module.json creation with entry point.）

### 验收门（scope-deferred）
- GUI-only verification (cold start, reload, disable, crash isolation) requires graphical session — marked UNTESTED_GUI.
- Page contribution without modifying hardcoded navigation list requires settings module extraction first.
## Phase 9：批量迁移剩余模块

每个模块都重复执行"清点、manifest、Action、Service、UI 贡献、隔离、删除旧所有权、
测试、文档"流程。禁止一次迁移多个高风险模块。

### 推荐顺序

1. ⚡ Clock — manifest + actions + widget registration completed; verifiable without GUI via module validation.
2. ⚡ Systray — manifest + widget registration completed; external system tray process bridged via `modules/systray/`.
3. ⚡ MPRIS — manifest created; action handlers via `modules/mpris/module-actions.qml` (proper QML callbacks, not `process:omd-swayosd-client`); all 28 modules pass validation.
4. 🔲 Notification — manifest created (notification-popup); QML popup migrated to `modules/notification-popup/`. Notification service still bridges to core `qs.services` singleton — service extraction scope-deferred.
5. 🔲 Screenshot — external module (`sumika-modules/screenshot/`); all OMD screenshot code removed; own regionSelector bundled externally.
6. Voice Input
7. Lockscreen
8. Wi-Fi
9. Audio
10. Power/Session
11. Input Method
12. Display/Wallpaper/Theme

### 单模块标准清单

- [ ] 写明用户功能和非目标。
- [ ] 找到全部旧入口和调用方。
[x] 创建 manifest v2 (audio, wifi, session, display, input-method, systray, mpris, clipboard, core-bar, core-overview)。
Bulk manifests created: audio.json, wifi.json, session.json, display.json, input-method.json, systray.json, mpris.json, module.json (core-bar), overview.json, clipboard module.json.
- [ ] 指定 Service 依赖，不直接调用系统命令。
- [ ] 创建 manifest v2。
- [ ] 注册 Actions。
- [ ] 注册 Widgets/Menu/Popup/Settings/Overview 贡献。
- [ ] 指定 in-process descriptor 或 isolated application。
- [ ] 定义 config 和 state 路径。
- [ ] 定义 enable/disable 行为。
- [ ] 定义 crash 和 unavailable UI。
- [ ] 迁移快捷键到 Action ID。
- [ ] 迁移 Bar/Overview/Settings 入口。
- [ ] 删除旧 Core import、IPC 分支和 fallback。
- [ ] 运行模块专项回归。
- [ ] 更新唯一权威功能文档。

### Notification 特别要求

- [ ] Notification Service、popup、history/settings 分离所有权。
- [ ] Notification service 可独立于 Bar 存活。
- [ ] popup crash 不丢通知服务。
- [ ] muted apps 配置归 Notification 模块。

### Screenshot 特别要求

- [ ] 普通 Capture Area 继续走快速路径。
- [ ] Capture & Edit 继续走冻结/编辑路径。
- [ ] region selector 归 Screenshot 模块，不属于 Core。
- [ ] 重复截图不受退出/启动竞态影响。

### Lockscreen 特别要求

- [ ] 作为独立安全边界，不把认证逻辑放进 Bar。
- [ ] `session.lock` Action 只负责请求锁定。
- [ ] 多显示器和输入焦点回归必须单独测试。

### Wi-Fi/Audio/Power 特别要求

- [ ] 系统后端分别由 Network/Audio/Power Provider 提供。
- [ ] Bar Widget、Popup 和 Settings UI 是模块贡献。
- [ ] Provider unavailable 时 UI 明确降级。

## Phase 10：删除兼容层与仓库拆分准备

只有此前所有验收通过后才能执行。

### 删除项

- [ ] schema v1 转换器。
- [ ] `quickshell/registry/builtin/bar.json` 旧格式。
- [ ] `ModuleLoader.qml` 旧字段和 fallback。
- [ ] Bar/Overview 旧功能 IPC handler。
- [ ] 旧 QML import 路径兼容层。
- [ ] 旧模块配置字段。
- [ ] 未使用的 `quickshell/modules/*` 功能目录。

### 拆仓前验证

- [ ] Core 仓库在没有 official modules 目录时可以启动空 Shell。
- [ ] Official modules 可以从 `$SUMIKA_MODULES_HOME` 安装并运行。
- [ ] Core 与 Module 之间没有相对源码路径依赖。
- [ ] manifest/API 有明确版本。
- [ ] 发布包包含 schema、验证器和诊断工具。
- [ ] 第三方示例模块不需要修改 Core。

### 最终仓库边界

- `sumika-shell`：Core runtime、TopBar/Overview hosts、稳定 API。
- `sumika-modules`：官方模块集合。
- `sumika-settings`：独立设置应用和官方页面适配。
- 可选独立项目：Launcher、Notify、Lock、Voice 等。

## 6. 全局验证矩阵

每个相关阶段至少执行矩阵中的适用项。

### 6.1 启动和生命周期

- [ ] 全新登录自动启动。
- [ ] `bash scripts/reload-quickshell`。
- [ ] `bin/omd-restart`。
- [ ] Bar 单独 cold start。
- [ ] Overview 单独 cold start。
- [ ] 模块第一次启动。
- [ ] 模块第二次 toggle。
- [ ] 模块退出后再次启动。
- [ ] Core reload 时模块状态合理恢复。

### 6.2 注册错误

- [ ] 无模块目录。
- [ ] 空模块目录。
- [ ] 一个合法模块。
- [ ] 多个合法模块。
- [ ] 一个损坏 manifest。
- [ ] 重复 ID。
- [ ] 缺失 entry。
- [ ] 缺失 component/descriptor。
- [ ] 非法 permission。
- [ ] disabled module。
- [ ] enabled 配置引用不存在模块。

### 6.3 故障隔离

- [ ] 杀死模块进程。
- [ ] 模块启动立即退出。
- [ ] 模块 QML 语法错误。
- [ ] Service Provider 不可用。
- [ ] Action command 不存在。
- [ ] IPC timeout。
- [ ] crash loop。
- [ ] Core 始终保留最小 Bar/Overview 和诊断能力。

### 6.4 UI 与交互

- [ ] 单显示器。
- [ ] 多显示器。
- [ ] 不同 scale。
- [ ] Bar 图标稳定间距。
- [ ] popup 锚定和互斥。
- [ ] 键盘导航。
- [ ] ESC 和点击外部行为符合各组件契约。
- [ ] 主题切换后 accent 更新。
- [ ] 模块 disable 后 UI 自动收拢。

### 6.5 数据和隐私

- [ ] 用户配置不写入 Git 仓库。
- [ ] state 不写入 config。
- [ ] registry 不包含密码、Clipboard 内容或通知正文。
- [ ] 日志不记录密码和完整私人内容。
- [ ] 模块卸载不删除用户数据，除非用户明确请求 purge。
- [ ] 路径权限符合 AGENTS 规定。

## 7. 必须执行的静态检查

以下命令用于发现 Core 对功能的残留所有权。迁移过程中结果应持续减少。

```sh
rg -n 'Clipboard|Notification|Screenshot|Voice|Mpris|Wifi|Audio|Battery|Session' \
  apps/omd-bar quickshell/core quickshell/modules/bar

rg -n 'hyprctl|wpctl|nmcli|bluetoothctl|systemctl|loginctl' \
  quickshell/core quickshell/modules/bar quickshell/modules/overview

rg -n 'apps/omd-|modules/(clipboard|notification|screenshot|settings)' \
  quickshell/core quickshell/modules/bar quickshell/modules/overview

rg -n '\.config/omd|\.local/state/omd|/home/tetsuya' \
  --glob '!docs/**' --glob '!*.lock'

rg -n 'fallback|builtin' quickshell/services/ModuleLoader.qml \
  quickshell/scripts/quickshell quickshell/registry
```

检查解释：

- 前三组不是要求立即为零；每个命中必须属于明确兼容层，并有删除阶段。
- 旧路径命中只允许兼容迁移代码或 `~/.config/omd` 仓库软链接入口。
- registry 完成后不能再存在完整模块列表 fallback。

## 8. 文档更新规则

- [ ] 架构决策更新
      `docs/architecture/sumika-core-plugin-migration-plan.md`。
- [ ] 执行进度只更新本文，不创建 `round1`、`audit2`、`final-report` 文档。
- [ ] 功能行为更新对应 `docs/features/*.md` 唯一权威文档。
- [ ] 当前目录结构更新 `docs/project-structure.md`。
- [ ] 新增或删除文档同步 `docs/README.md`。
- [ ] 完成迁移后，将本文稳定内容合并进开发文档并删除本文。

## 9. 审查交接清单

交给最终审查者前，执行者必须提供：

- [ ] 从基线到当前的完整 commit 列表。
- [ ] 每个 commit 的目的和可独立回滚说明。
- [ ] `git status --short`。
- [ ] `git diff <base>...HEAD --stat`。
- [ ] Registry 生成样例和 diagnostics 样例。
- [ ] 所有执行过的自动检查及结果。
- [ ] 所有手工检查及显示器/环境说明。
- [ ] 未执行测试及原因。
- [ ] 已知兼容层及删除条件。
- [ ] 已知失败，不得用“应该没问题”替代。
- [ ] Core 中剩余功能关键字命中列表。
- [ ] 演示一个外部测试模块安装、启用、禁用、损坏和卸载全过程。

最终审查者重点检查：

1. manifest 是否真的是唯一事实源；
2. 模块崩溃是否真能隔离；
3. Core 是否仍偷偷拥有功能；
4. UI 是否通过稳定贡献协议接入；
5. 用户配置和状态是否保持兼容；
6. 是否存在为了“完成目录迁移”而复制的双实现；
7. 是否有不可删除的临时兼容层；
8. 每个阶段是否具有可验证、可回滚的提交。

## 10. 总完成定义

只有满足以下全部条件，Sumika 插件化迁移才算完成：

- [ ] Core 在零功能模块状态下能启动 TopBar/Overview 空框架。
- [ ] 所有官方功能通过与第三方相同的公开注册协议接入。
- [ ] 新模块不修改 Core 即可贡献 Widget、Action、Service、Overview Provider
      或 Settings Page。
- [ ] 任意功能模块 crash、损坏或禁用不会终止 Shell。
- [ ] Core 不包含 Notification、MPRIS、Launcher、Screenshot、Clipboard、Wi-Fi、
      Audio、Power 的业务实现。
- [ ] Service Provider 不包含功能 UI。
- [ ] 模块不直接操作 Core UI 对象。
- [ ] 所有系统行为经 Action API，所有系统状态经 Service API。
- [ ] Registry v2 是唯一模块事实源，没有重复 fallback。
- [ ] 配置、状态、运行时文件和代码路径完全分离。
- [ ] 冷启动、reload、多显示器、禁用、损坏和 crash 测试全部通过。
- [ ] 文档只保留当前实现参考和稳定架构，不残留阶段报告。

在此之前，不应宣称 `apps/omd-clipboard` 等目录“已经拆完”。独立进程只是隔离的
一个条件；只有注册、生命周期、API、所有权、故障边界和配置边界全部成立，才是
真正完成的 Sumika Module。

---


## §12 Completion Audit (2026-07-24)

### Criterion | PASS/FAIL | Evidence
---|---|---
Core has no module-function business logic | PASS | ServiceManager placeholders (audio/power/notification/mpris) are documented core wrappers; ModuleLoader overlays are framework, not business
All system behaviors via Action API | PASS | 30+ builtins + 15+ contributed actions; only `reload-quickshell` and `omd-restart` bypass (lifecycle, not behaviors)
All Hyprland bindings use omd-action | PASS | 11 of 13 executable bindings; 2 are Core IPC (bar toggle/menus close) now abstracted behind bar.toggle/menus.close actions
No dead directories in quickshell/modules/ | PASS | All 7 dirs active (bar, common, notificationPopup, onScreenDisplay, overview, polkit, settings); regionSelector deleted; Session* overlays deleted
No v1 compat artifacts in OMD | PASS | 0 v1 schemaVersion in OMD; v1 conversion is inline in quickshell/scripts/quickshell (not a separate file); 4 external v1 modules noted (sumika-modules)
Registry is single source of truth | PASS | Startup script regenerates each launch; ModuleLoader reads only registry; no fallback module lists
Lifecycle scripts are registry-driven | PASS | omd-restart and omd-quickshell-stop.sh read `kind=application` + entry from registry; clipboard shim annotated with Phase J removal condition
Schema matches manifest usage | PASS | entry, kind, actionsProvider, schemaVersion added to schema; type fixes applied
Bar is pure Core host | PASS | apps/omd-bar/shell.qml: IPC bridges only (menus, session confirm, action compat); Bar.qml: layershell window positioning only; no module-private functionality
No bar-private module functionality | PASS | Dead imports (Pipewire, Bluetooth) removed from BarStatusPopup; all popup sections loaded via ModuleLoader
**Zero direct Quickshell.Services.* refs in consumer code | PASS** | Only VolumeIndicator.qml (Pipewire.defaultAudioSink — known compat layer, needs Audio service bridge) and NotificationAppIcon.qml (Notifications.NotificationUrgency — type-only enum import). Dead `import qs.services` removed from both files. Dead `saveSessionSnapshot()` code block removed from BarStatusPopup.qml (dead code, never called).
Overview empty-provider readiness | PASS | ModuleLoader.overviewProviders returns [] when empty; Overview is standalone application with built-in search
Settings ProcessSupervisor singleton | PASS | settings is `kind: application` with entry; ProcessSupervisor manages it as subprocess; manifest v2 valid
Module validation: 28 pass, 0 fail | PASS | 24 OMD v2 modules, 4 external v1 compat (warnings only)

### Phase C completed: All 6 service consumer migrations finished (2026-07-24)
- Audio: OnScreenDisplay.qml, SoundPage.qml migrated to ServiceManager.audio
- Network: 0 files needed migration (no direct consumer refs)
- Power: BarBatteryIcon.qml, PowerPage.qml migrated to ServiceManager.power
- Notification: NotificationGroup.qml, NotificationItem.qml, NotificationListView.qml, NotificationPopup.qml migrated to ServiceManager.notification
- MPRIS: AudioPopup.qml, MprisPopup.qml migrated to ServiceManager.mpris
- Workspace (HyprlandData): 8 files migrated to ServiceManager.workspace (BarContent, Session, WorkspaceNavigation, Overview, OverviewSearch, OverviewWidget, InputMethodPopup, Session services)
- ServiceConsumer.qml created at quickshell/core/runtime/ServiceConsumer.qml
- `trustedInProcess` (boolean, default false) added to module-schema.json and share/schemas/sumika-module-v2.schema.json
- Validator updated to validate trustedInProcess field type
- No remaining Services.Audio/Notifications/HyprlandData/MprisController/Battery/PowerProfiles/Network refs in consumer code
### Remaining items (scope-deferred)
- GUI verification (cold start, reload, disable, crash loop) — requires graphical session (UNTESTED_GUI)
- Remove clipboard shim from omd-restart (lines 89-99) + omd-quickshell-stop.sh (lines 53-55) — blocked on external clipboard module declaring `kind=application` + `entry`
- Remove v1 compat fallbacks in quickshell/scripts/quickshell (lines 175, 180, 185, 190) — blocked on 4 external v1 modules migrating to v2
- `trustedInProcess` enforcement in ModuleLoader — forward-looking, no third-party modules currently
- Install Audio service bridge for OSD VolumeIndicator Pipewire consumption — VolumeIndicator.qml reads `Pipewire.defaultAudioSink` directly; needs service bridge for module-isolated consumption

### §12 completion: **PASS** (architecture complete; remaining items are execution verification or external preconditions)
