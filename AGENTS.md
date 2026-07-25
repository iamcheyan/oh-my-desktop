# oh-my-desktop / Sumika Shell

Unified desktop configuration for the current Omarchy + Quickshell session.
All runtime files — user config, Quickshell UI, and the Omarchy framework —
live in this single repo.

**Public name**: Sumika Shell.
**Technical names** (omd-* commands, org.omd.* IDs, systemd units) keep the
`omd` prefix — rename deferred.

## Quick Start

```sh
git clone git@github.com:iamcheyan/oh-my-desktop.git ~/development/OMD
cd ~/development/OMD && ./Init.sh
```

`Init.sh` creates runtime symlinks (`~/.config/quickshell → repo/quickshell`,
`~/.config/omd → repo`). Re-run safely after pulls.

## Data Layout

|Role|Path|Managed by|
|---|---|---|
|Code + QML + assets|`~/development/OMD/`|git|
|All modules (bar, wifi, settings, launcher, audio, display, overview, systray, power-indicator, etc.)|`OMD/quickshell/modules/` (17 core modules)|git (main repo)|
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
~/.config/omd         → ~/development/OMD               # bin/ scripts + apps/ dirs
```

`~/.config/omd` 是 QML/shell 找到 `bin/omd-*` 和 `apps/` 的主入口。`~/.config/sumika-shell/` 是并存的真实目录，不放可执行脚本。

## Runtime

- **Hyprland**: `hypr/hyprland.lua` loads `hypr/default/` then `hypr/*.lua`.
* **Quickshell config**: user override at `~/.config/sumika-shell/sumika.json` (unified config via sumika.json), baseline at `defaults/config/quickshell/config.json`.
- **Themes**: `OmarchyTheme.qml` reads `~/.local/state/sumika-shell/theme/current/colors.toml`; 22 themes in `share/themes/`.
- **Wallpaper**: `swaybg` via autostart; `bin/omd-wallpaper` handles rotation. State at `~/.local/state/sumika-shell/wallpaper/`.
- **Quickshell Shell UI**: `quickshell/` root with `modules/` subdirectories for each component.
- **Services**: `quickshell/services/` — QML singletons via `import qs.services`.
- **TUI style**: `common/TuiStyle.qml` — add tokens there, not hard-coded colors.
- **Bar popups**: `BarStatusPopup.qml` — do NOT add per-module `XxxInfoPopup.qml`.
- **Extensions**: `~/.local/share/sumika-shell/extensions/<id>/` — see [Extensions](#extensions) section below.
- **Core modules vs Extensions**: 17 core modules live in `quickshell/modules/` and are always available. External extensions cannot override core modules — they are silently skipped on ID conflict.

## Editing

### Quickshell

- Shared widgets: `quickshell/modules/common/widgets/`.
- Services: QML singletons via `import qs.services`.
- TUI style: `common/TuiStyle.qml` — add tokens there, not hard-coded colors.
- Default module QML: `modules/<name>/` — 17 core modules in this repo.
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
|CLI|`omd-modules extensions`|
|诊断|`omd-doctor` + extensions section|

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
- Use `omd-modules extensions` to list installed extensions.
- Run `omd-doctor` to diagnose extension issues.
- **External module services MUST NOT** live in `quickshell/services/`. Service files for a module must be placed inside the module's own directory and registered via its `qmldir` as a singleton (`singleton <Type> 1.0 <File>.qml`). The former `InputMethod.qml`, `KeyboardRemap.qml` and any screenshot-session service are examples that should follow this pattern — core services only for core singletons.
### Omarchy / Hyprland

- Config: `hypr/*.lua`. Autostart: `hypr/autostart.lua`. Reload: `hyprctl reload`.

## TUI Terminal Action Pattern

1. Launcher cascade: `xdg-terminal-exec --app-id=org.omd.<purpose>` → `foot --app-id=...` → `kitty --class=...`
2. Unique `app-id`/`class` per purpose for Hyprland floating rules.
3. Naming: `org.omd.<purpose>` (lowercase, dash-separated).
4. Launch detached: `subprocess.Popen(..., start_new_session=True)` with stdin/stdout/stderr to `/dev/null`.
5. Add Hyprland window rule in `hypr/looknfeel.lua`.

## Path API

|Env var|Fallback|Used by|
|---|---|---|
|`SUMIKA_SHELL_CONFIG_HOME`|`$XDG_CONFIG_HOME/sumika-shell` → `~/.config/sumika-shell`|Shell scripts|
|`SUMIKA_SHELL_STATE_HOME`|`$XDG_STATE_HOME/sumika-shell` → `~/.local/state/sumika-shell`|Shell scripts|
|`SUMIKA_SHELL_ROOT`|`$OMD_ROOT` → `~/.config/omd` (symlink to repo)|Shell scripts|
|`Directories.config + "/sumika-shell"`|—|QML (config path)|
|`Directories.sumikaStateHome`|`$XDG_STATE_HOME/sumika-shell`|QML (state path)|

|`SUMIKA_SHELL_EXTENSIONS_DIR`|`$XDG_DATA_HOME/sumika-shell/extensions` → `~/.local/share/sumika-shell/extensions`|Shell scripts|
**QML**: use `Directories.sumikaStateHome + "/..."` for runtime state. It honors `SUMIKA_SHELL_STATE_HOME`; do not append another `sumika-shell` suffix. Do NOT use `Qt.environmentVariable()` (unsupported).

## Git

- Root: `~/development/OMD`.
- Don't commit: `.migration-backups/`, Quickshell `.state/`, nested `.git`.
- Run `~/.config/omd/bin/omd-doctor` before pushing.
- No test framework; verify by `hyprctl reload` + `omd-restart`.

## Planning Docs

All design docs → `docs/` inside repo. Never save to `/tmp` or outside project.
