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

| Role | Path | Managed by |
|------|------|-----------|
| Code + QML + assets | `~/development/OMD/` | git |
| Default modules (bar 按钮、弹出面板、overlay) | `OMD/modules/` (15 个) | git (主仓库) |
| External modules (第三方、非核心) | `$SUMIKA_MODULES_HOME` → `~/development/sumika-modules/` (28 个) | git (separate repo) |
| User config (overrides, launchers, keyboard profiles, notifications) | `~/.config/sumika-shell/` | chezmoi |
| Runtime state (themes, wallpaper, keyd generated config) | `~/.local/state/sumika-shell/` | generated, not committed |
| Theme library | `~/development/OMD/share/themes/` (22 themes) | git |
| Terminal configs (foot/kitty/alacritty/ghostty) | `~/.config/{foot,kitty,...}/` | chezmoi |

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
- **Themes**: `share/bin/omarchy-theme-*` → snapshot to `~/.local/state/sumika-shell/theme/current/`.
- **Wallpaper**: `swaybg` via autostart; `bin/omd-wallpaper` handles rotation. State at `~/.local/state/sumika-shell/wallpaper/`.
- **Terminal themes**: `~/.local/state/sumika-shell/theme/current/{foot,kitty,alacritty,ghostty}.*` — include from chezmoi-managed terminal configs.
- **Neovim**: opt-in, links LazyVim drop-in that reads `~/.local/state/sumika-shell/theme/current/neovim.lua`.
- **Restart**: `~/.config/omd/bin/omd-restart` (via symlink to repo).
- **Doctor**: `~/.config/omd/bin/omd-doctor`.
- **Modules**: `OMD/modules/` (default core modules) loaded first; `$SUMIKA_MODULES_HOME` (external modules) loaded second. Duplicate IDs from external modules are skipped — default modules always win.

## Editing

### Quickshell

- Shared widgets: `quickshell/modules/common/widgets/`.
- Services: QML singletons via `import qs.services`.
- TUI style: `common/TuiStyle.qml` — add tokens there, not hard-coded colors.
- Default module QML: `modules/<name>/` — 15 core modules in this repo.
- External modules: `$SUMIKA_MODULES_HOME/<name>/` — separate repo.
- Bar popups: `BarStatusPopup.qml` — do NOT add per-module `XxxInfoPopup.qml`.
- Voice: `AudioButton.qml` + `BarStatusPopup.qml`, hotkey ALT+A. Trigger via `qs -p ~/.config/omd/apps/omd-bar ipc call voice toggle`.

### Omarchy / Hyprland

- Config: `hypr/*.lua`. Autostart: `hypr/autostart.lua`. Reload: `hyprctl reload`.

## TUI Terminal Action Pattern

1. Launcher cascade: `xdg-terminal-exec --app-id=org.omd.<purpose>` → `foot --app-id=...` → `kitty --class=...`
2. Unique `app-id`/`class` per purpose for Hyprland floating rules.
3. Naming: `org.omd.<purpose>` (lowercase, dash-separated).
4. Launch detached: `subprocess.Popen(..., start_new_session=True)` with stdin/stdout/stderr to `/dev/null`.
5. Add Hyprland window rule in `hypr/looknfeel.lua`.

## Path API

| Env var | Fallback | Used by |
|---------|----------|---------|
| `SUMIKA_SHELL_CONFIG_HOME` | `$XDG_CONFIG_HOME/sumika-shell` → `~/.config/sumika-shell` | Shell scripts |
| `SUMIKA_SHELL_STATE_HOME` | `$XDG_STATE_HOME/sumika-shell` → `~/.local/state/sumika-shell` | Shell scripts |
| `SUMIKA_SHELL_ROOT` | `$OMD_ROOT` → `~/.config/omd` (symlink to repo) | Shell scripts |
| `Directories.config + "/sumika-shell"` | — | QML (config path) |
| `Directories.sumikaStateHome` | `$XDG_STATE_HOME/sumika-shell` | QML (state path) |
|`SUMIKA_MODULES_HOME`|`~/development/sumika-modules/` (also configurable via `quickshell/config.json:modules.dir`)|Shell scripts, Python tools|`OMD/modules/` takes priority on duplicate IDs|

**Shell**: `. "$_omd_root/lib/paths.sh"` → all vars.
**Lua**: `local paths = require("default.hypr.paths")` → `paths.omd_root`, `paths.config_home`, `paths.state_home`.
**QML**: use `Directories.sumikaStateHome + "/..."` for runtime state. It honors `SUMIKA_SHELL_STATE_HOME`; do not append another `sumika-shell` suffix. Do NOT use `Qt.environmentVariable()` (unsupported).

## Git

- Root: `~/development/OMD`.
- Don't commit: `.migration-backups/`, Quickshell `.state/`, nested `.git`.
- Run `~/.config/omd/bin/omd-doctor` before pushing.
- No test framework; verify by `hyprctl reload` + `omd-restart`.

## Planning Docs

All design docs → `docs/` inside repo. Never save to `/tmp` or outside project.
