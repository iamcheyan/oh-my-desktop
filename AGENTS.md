# Sumika Shell

Unified desktop configuration for the current Omarchy + Quickshell session.
All runtime files — user config, Quickshell UI, and the Omarchy framework —
live in this single repo.

**Public name**: Sumika Shell.
**Technical namespace**: `sumika-*` commands,
`io.github.iamcheyan.sumika.*` app IDs, and `sumika-*` systemd units.
The retired `omd` technical namespace is not supported.

## Quick Start

```sh
git clone git@github.com:iamcheyan/oh-my-desktop.git ~/development/OMD
cd ~/development/OMD && ./Init.sh
```

`Init.sh` creates the runtime Quickshell symlink
(`~/.config/quickshell → repo/quickshell`) and installs the Sumika session.
Re-run safely after pulls.

## Data Layout

|Role|Path|Managed by|
|---|---|---|
|Code + QML + assets|`~/development/OMD/`|git|
|All core modules (bar, wifi, settings, launcher, audio, display, overview, systray, power-indicator, etc.)|`OMD/quickshell/modules/` (11 core modules)|git (main repo)|
|User config (overrides, launchers, keyboard profiles, notifications)|`~/.config/sumika-shell/`|chezmoi|
|Extensions|`~/.local/share/sumika-shell/extensions/<id>/`|user-installed, discovered at startup|
|Theme library|`~/development/OMD/share/themes/` (22 themes)|git|
|Terminal configs (foot/kitty/alacritty/ghostty)|`~/.config/{foot,kitty,...}/`|chezmoi|
|Runtime state (themes, wallpaper, keyd generated config)|`~/.local/state/sumika-shell/`|generated, not committed|

### chezmoi: `~/.config/sumika-shell/` 规则

**`~/.config/sumika-shell/` 是普通配置目录，权限 0644/0755。**
`chezmoi add ~/.config/sumika-shell/` 时，所有条目 **禁止使用 `private_` 前缀**。

如果 chezmoi 自动添加了 `private_` 前缀（因目录有 0700 权限），必须立即改回普通文件名并 `chezmoi apply` 修复权限。

### Runtime Symlinks

```
~/.config/quickshell  → ~/development/OMD/quickshell   # QML root
```

`SUMIKA_SHELL_ROOT` points QML/shell code at the repository root.
`~/.config/sumika-shell/` is the real user configuration directory and does
not contain repository executables.

## Runtime

- **Hyprland**: `hypr/hyprland.lua` loads `hypr/default/` then `hypr/*.lua`.
* **Quickshell config**: user override at `~/.config/sumika-shell/sumika.json` (unified config via sumika.json), baseline at `defaults/config/quickshell/config.json`.
- **Themes**: `OmarchyTheme.qml` reads `~/.local/state/sumika-shell/theme/current/colors.toml`; 22 themes in `share/themes/`.
- **Wallpaper**: `swaybg` via autostart; `sumika-wallpaper` handles rotation. State at `~/.local/state/sumika-shell/wallpaper/`.
- **Quickshell Shell UI**: `quickshell/` root with `modules/` subdirectories for each component.
- **Services**: `quickshell/services/` — QML singletons via `import qs.services`.
- **TUI style**: `common/TuiStyle.qml` — add tokens there, not hard-coded colors.
- **Bar popups**: `BarStatusPopup.qml` — do NOT add per-module `XxxInfoPopup.qml`.
- **Extensions**: `~/.local/share/sumika-shell/extensions/<id>/` — see [Extensions](#extensions) section below.
- **Core modules vs Extensions**: 11 core modules live in `quickshell/modules/` and are always available. External extensions cannot override core modules — they are silently skipped on ID conflict. The manifest ID is canonical; a QML-safe directory name may differ (for example `notification-popup` uses `notificationPopup/`).

## Editing

### Quickshell

- Shared widgets: `quickshell/modules/common/widgets/`.
- Services: QML singletons via `import qs.services`.
- TUI style: `common/TuiStyle.qml` — add tokens there, not hard-coded colors.
- Default module QML: `modules/<name>/` — 11 core modules in this repo.
- **Bar popups**: `BarStatusPopup.qml` — do NOT add per-module `XxxInfoPopup.qml`.

### Core Modules (Product Floor)

The following modules are part of the core product floor and require no external installation:

|Module|Function|Dependencies|
|---|---|---|
|`bar`|Main bar container (left/right slots, popups)|—|
|`clock`|Clock widget (far-right bar)|—|
|`workspaces`|Workspace indicators (left bar)|—|
|`systray`|System Tray (SNI icons, right bar)|Quickshell.Services.SystemTray (built-in), TrayService|
|`power-indicator`|Power + XKB indicator (far-right bar)|Battery, PowerProfiles, HyprlandXkb services|
|`wifi`|Wi-Fi button + popup|Network service|
|`audio`|Audio button + popup|Audio service|
|`display`|Display (brightness) button + popup|Brightness service|
|`overview`|Window overview / search|OverviewWidget|
|`launcher`|App launcher button (left bar)|AppSearch service|
|`settings`|Settings dialog (app)|—|
|`notification-popup`|Notification popup display|Notifications service|

**Rules:**
- Core modules are always enabled (cannot be disabled through `modules.disabled` config).
- External extensions with the same ID are silently skipped at startup.
- New core modules must be added to `ModuleLoader.productFloorModuleIds`.
- Core service singletons live in `quickshell/services/` (e.g. `TrayService`).
- Core module QML files live in `quickshell/modules/<id>/` with a `module.json` manifest.


### Extensions

Overview of the extension (external module) system:

|方面|具体|
|---|---|
|安装目录|`~/.local/share/sumika-shell/extensions/<id>/`|
|约定文件|`module.json`、`qmldir`、`bin/`（可选）|
|发现时机|Quickshell 启动时，core 模块扫描之后|
|冲突策略|core 模块永远优先，同名扩展静默跳过|
|QML import|自动 symlink 到运行时 import root|
|`bin/`|自动加入 `PATH`|
|CLI|`sumika-modules extensions`|
|诊断|`sumika-doctor` + extensions section|

### Extension Directory Structure

```
<id>/
  module.json       # v2 manifest (required)
  qmldir            # QML module declaration (required for `import qs.modules.<id>`)
  *.qml             # QML source files
  bin/              # Optional: executables auto-added to PATH at startup
```

**Rules:**
- Extensions are scanned at Quickshell startup, after core modules.
- **Core modules always win** on ID conflict — extension is silently skipped.
- Extension QML imports (`import qs.modules.<id>`) work automatically via runtime symlink.
- Extension `bin/` is added to `PATH` each startup.
- Use `sumika-modules extensions` to list installed extensions.
- Run `sumika-doctor` to diagnose extension issues.
- **External module services MUST NOT** live in `quickshell/services/`. Service files for a module must be placed inside the module's own directory and registered via its `qmldir` as a singleton (`singleton <Type> 1.0 <File>.qml`). The former `InputMethod.qml`, `KeyboardRemap.qml` and any screenshot-session service are examples that should follow this pattern — core services only for core singletons.

### Desktop Launchers (`contributes.launchers`)

扩展通过 `module.json` 的 `contributes.launchers` 声明桌面快捷方式，由 shell 框架**自动同步**。**不要写 QML 管理 .desktop。**

👉 完整参考：[docs/launchers-contract.md](docs/launchers-contract.md)
### Omarchy / Hyprland

- Config: `hypr/*.lua`. Autostart: `hypr/autostart.lua`. Reload: `hyprctl reload`.

## TUI Terminal Action Pattern

1. Launcher cascade: `xdg-terminal-exec --app-id=io.github.iamcheyan.sumika.<purpose>` → `foot --app-id=...` → `kitty --class=...`
2. Unique `app-id`/`class` per purpose for Hyprland floating rules.
3. **app-id 不能包含下划线**。Wayland / 终端会把下划线静默丢弃（例：`sumika_settings_wallpaper_tui` 变成 `sumikasettingswallpapertui`），导致 Hyprland window 规则匹配不上。只允许 `[:alnum:]`（见 `share/bin/omarchy-launch-tui` 的 `tr -cd '[:alnum:]'`）。
4. Launch detached: `subprocess.Popen(..., start_new_session=True)` with stdin/stdout/stderr to `/dev/null`。
5. 在 `hypr/looknfeel.lua` 的 `sumika_tui_ids` 列表里加上 app-id 的**实际 class 名**（终端去下划线后的形式）。`o.window()` 规则统一用 `tui_rule`（`float=true, center=true, size={1180,760}`）。

### `omarchy-launch-tui` 机制

`share/bin/omarchy-launch-tui`（`sumika-launch-tui` 委托给它）负责把 TUI 脚本启动到终端里：
- 从脚本文件名提取 app-id（去下划线、去扩展名）。
- 用 `xdg-terminal-exec --app-id=...` 启动，回退到直接调 `foot` / `kitty` 。
- 通过 `uwsm-app` 包装确保 app-id 正确传递给 compositor。
- 调用方（QML 的 `Quickshell.execDetached` 或 shell 脚本）直接调 `sumika-launch-tui <script-path> [args...]`，不自行构造终端命令。

**不要在 QML 里自己拼终端命令。** 统一走 `sumika-launch-tui`。

### 添加新 TUI 工具步骤

1. 写脚本到 `bin/`（或扩展的 `bin/`）。
2. 确认脚本启动方式 —— 如果走 `sumika-launch-tui`（推荐），`omarchy-launch-tui` 从文件名 `tr -cd '[:alnum:]'` 生成 app-id（去下划线）。如果走硬编码 `xdg-terminal-exec --app-id=...`，以实际传的 app-id 为准。
3. 在 `hypr/looknfeel.lua` 的 `sumika_tui_ids` 里加上**实际 class 名**（无下划线形式）。如果一个 TUI 有多个启动路径（主路径走 `sumika-launch-tui`、回退路径走硬编码 app-id），**两个都要加**，因为哪个路径实际被命中有不确定性。
4. 在需要启动的地方调 `sumika-launch-tui <script-path>`。
5. `hyprctl reload` 使规则生效。
6. 验证：启动 TUI，`hyprctl -j clients` 检查 `floating=true` 和 `size=[1180,760]`。

> ⚠️ **扩展 TUIs 常见陷阱**：扩展的 launcher 脚本可能在 `sumika-launch-tui` 主路径和硬编码回退路径中使用不同的 app-id。例如 voice 扩展：`sumika-launch-tui sumika-settings-voice-tui` 生成 `sumikasettingsvoicetui`，而回退路径用 `voicesettings`。两个 app-id 都需要加到 `sumika_tui_ids` 里。
>
> 排查：`grep -r 'app-id=\|--class= \|sumika-launch-tui' ~/.local/share/sumika-shell/extensions/<id>/` 找出所有实际使用的 app-id。

## Path API

|Env var|Fallback|Used by|
|---|---|---|
|`SUMIKA_SHELL_CONFIG_HOME`|`$XDG_CONFIG_HOME/sumika-shell` → `~/.config/sumika-shell`|Shell scripts|
|`SUMIKA_SHELL_STATE_HOME`|`$XDG_STATE_HOME/sumika-shell` → `~/.local/state/sumika-shell`|Shell scripts|
|`SUMIKA_SHELL_ROOT`|repository root exported by the session wrapper|Shell scripts|
|`Directories.config + "/sumika-shell"`|—|QML (config path)|
|`Directories.sumikaStateHome`|`$XDG_STATE_HOME/sumika-shell`|QML (state path)|

|`SUMIKA_SHELL_EXTENSIONS_DIR`|`$XDG_DATA_HOME/sumika-shell/extensions` → `~/.local/share/sumika-shell/extensions`|Shell scripts|
**QML**: use `Directories.sumikaStateHome + "/..."` for runtime state. It honors `SUMIKA_SHELL_STATE_HOME`; do not append another `sumika-shell` suffix. Do NOT use `Qt.environmentVariable()` (unsupported).

## Git

- Root: `~/development/OMD`.
- Don't commit: `.migration-backups/`, Quickshell `.state/`, nested `.git`.
- Run `bin/sumika-doctor` before pushing.
- No test framework; verify by `hyprctl reload` + `sumika-restart`.

## Planning Docs

All design docs → `docs/` inside repo. Never save to `/tmp` or outside project.
