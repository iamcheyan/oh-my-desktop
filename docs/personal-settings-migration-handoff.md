# 个人化设置迁移 — 交接文档

> **给执行智能体的说明**：本文档是完整的工作交接。你需要完成 Phase 2–5 的所有任务。Phase 1 已完成作为参考模式。请严格按本文档执行，每完成一个 Phase 后运行验证步骤，全部完成后提交。

---

## 项目背景

**项目**：oh-my-desktop (Sumika Shell) — 基于 Omarchy + Quickshell 的公开桌面环境。
**仓库**：`~/development/OMD`
**公开名**：Sumika Shell。技术名保留 `omd` 前缀。

### 架构约定

| 角色 | 路径 | 管理方式 |
|---|---|---|
| 代码 + QML + assets | `~/development/OMD/` | git |
| 用户配置（覆盖、launchers、键盘、通知） | `~/.config/sumika-shell/` | chezmoi |
| 运行时状态（主题、wallpaper、keyd 生成配置） | `~/.local/state/sumika-shell/` | 生成，不提交 |

**核心原则**：仓库里的 `defaults/` 和 `hypr/default/` 是所有人共用的基线。个人设置应在 `~/.config/sumika-shell/` 覆盖。

### Path API

| 变量 | fallback | 用途 |
|---|---|---|
| `SUMIKA_SHELL_CONFIG_HOME` | `$XDG_CONFIG_HOME/sumika-shell` → `~/.config/sumika-shell` | Shell 脚本 |
| `SUMIKA_SHELL_STATE_HOME` | `$XDG_STATE_HOME/sumika-shell` → `~/.local/state/sumika-shell` | Shell 脚本 |
| `SUMIKA_SHELL_ROOT` / `OMD_ROOT` | `~/.config/omd` (symlink to repo) | Shell 脚本 |
| `Directories.config + "/sumika-shell"` | — | QML |
| `Directories.sumikaStateHome` | `$XDG_STATE_HOME/sumika-shell` | QML |

### Hyprland 配置加载链

```
hypr/hyprland.lua
  → require("default.hypr.base")     ← 基线层
  → dofile(hypr/monitors.lua)         ← 显示器布局
  → require("input")                  ← hypr/input.lua
  → require("bindings")              ← hypr/bindings.lua
  → require("looknfeel")             ← hypr/looknfeel.lua
  → require("autostart")             ← hypr/autostart.lua
  → ~/.config/sumika-shell/hypr/*.lua ← 用户覆盖层（Phase 1 新增）
  → require("default.hypr.toggles")
  → require("window_rules") (if exists)
```

用户覆盖层在 Phase 1 中加入 `hypr/hyprland.lua`，会加载 `~/.config/sumika-shell/hypr/{input,bindings,looknfeel,autostart}.lua`（如果文件存在）。

### Quickshell 配置系统

- 基线默认值：`defaults/config/quickshell/config.json` + `quickshell/modules/common/Config.qml`（JsonObject 默认值）
- 用户覆盖：`~/.config/sumika-shell/quickshell/config.json`
- `Config.qml` 的 `JsonAdapter` 自动合并两层
- 新增配置项时必须同时在 `config.json` 和 `Config.qml` 加默认值

### 验证方法

- **编译**：`cd ~/development/OMD && timeout 8 qs -p apps/omd-bar 2>&1 | grep -E "ERROR|Loaded"` — 应显示 `Configuration Loaded`
- **Lua 语法**：`lua -e "loadfile('hypr/hyprland.lua')"` — 无输出即通过
- **JSON 验证**：`python3 -c "import json; json.load(open('path'))"`
- **Python 语法**：`python3 -c "import py_compile; py_compile.compile('path', doraise=True)"`
- **Hyprland reload**：`hyprctl reload`（用户操作）
- **Quickshell restart**：`omd-restart`（用户操作）
- **无测试框架**：验证靠编译 + 运行

### Git 约定

- 不要提交：`.migration-backups/`、Quickshell `.state/`、nested `.git`
- 提交前不需要跑 `omd-doctor`（那是 push 前的）
- 每完成一个 Phase 可以单独提交

---

## Phase 1 已完成（参考模式）

> 以下已完成，作为后续 Phase 的参考模式。不要重复修改这些文件。

### 输入法模块化

**改了什么**：
1. `defaults/config/quickshell/config.json` 新增 `inputMethod` 节
2. `quickshell/modules/common/Config.qml` 新增 `inputMethod` JsonObject
3. `bin/omd-input-method` 重写：硬编码 SCHEMAS → 外部 JSON 加载 + `detect_backend()` + `schemas` 子命令
4. `quickshell/services/InputMethod.qml`：硬编码 schemas → 从 `status` 输出动态填充
5. `quickshell/modules/bar/modules/InputMethodButton.qml`：`visible` 绑定到 config 开关
6. `hypr/default/hypr/autostart.lua`：删除 fcitx5 启动行
7. `hypr/bindings.lua`：Rime 绑定改为注释模板
8. `hypr/hyprland.lua`：新增用户配置加载层
9. `omarchy/fcitx5/` 删除，移到 `~/.config/sumika-shell/fcitx5/`
10. 新建 `defaults/config/input-method/schemas.json`（空模板）
11. 用户配置模板写入 `~/.config/sumika-shell/{hypr/autostart.lua, hypr/bindings.lua, input-method/schemas.json}`

**模式总结**：每个个人设置迁移遵循三步：
1. 仓库基线改为中立默认（通常禁用或留空）
2. 加载逻辑改为从用户配置读取
3. 用户配置模板写入 `~/.config/sumika-shell/`

提交：`65c3637`

---

## Phase 2：键盘与 keyd 迁移

### 目标
把日文键盘布局和个人 keyd 设备清单从仓库移到用户配置。

### 任务 2.1：迁移 `hypr/input.lua` 到用户配置

**现状**：
- `hypr/input.lua` 是个人覆盖层（在 `require("input")` 时加载）
- 内容硬编码 `kb_layout = "jp"`（日文布局）
- `hypr/default/hypr/input.lua` 是基线，内容是 `kb_layout = "us"`（通用）

**操作**：
1. 读取 `~/development/OMD/hypr/input.lua` 全文
2. 复制到 `~/.config/sumika-shell/hypr/input.lua`（确保开头加 `local paths = require("default.hypr.paths")` 如果用到 paths）
3. 把仓库的 `hypr/input.lua` 改为仅含注释，说明个人键盘布局应放在用户配置：

```lua
-- Personal keyboard input settings (layout, variant, repeat rate, etc.).
-- Override in ~/.config/sumika-shell/hypr/input.lua.
-- The default layer (hypr/default/hypr/input.lua) sets kb_layout = "us".
```

**注意**：`hypr/default/hypr/input.lua` 已经有 `kb_layout = "us"` 基线。仓库的 `hypr/input.lua` 是覆盖层。把覆盖层清空后，默认 `us` 布局生效。用户通过 `~/.config/sumika-shell/hypr/input.lua` 覆盖回 `jp`。

**验证**：
- `lua -e "loadfile('hypr/input.lua')"` 无错误
- `~/.config/sumika-shell/hypr/input.lua` 存在且含 `kb_layout = "jp"`

### 任务 2.2：迁移 `keyboard-remap/profiles.json` 到用户配置

**现状**：
- `keyboard-remap/profiles.json` 含 5 个个人设备（apple-spi-keyboard、compx-2-4g-receiver、guo-magic-keyboard、logitech-usb-receiver、minila-r-convertible）
- 每个设备有个人 preset（alt-win-swap、muhenkan-meta: f13 等）
- `keyboard-remap/keyd.generated.conf` 是生成产物

**操作**：
1. 复制 `keyboard-remap/profiles.json` 到 `~/.config/sumika-shell/keyboard-remap/profiles.json`
2. 在仓库创建空模板 `defaults/config/keyboard-remap/profiles.json`：
```json
{
  "version": 1,
  "devices": {}
}
```
3. 修改读取 `profiles.json` 的脚本，改为从 `SUMIKA_SHELL_CONFIG_HOME/keyboard-remap/profiles.json` 读取，fallback 到仓库默认模板
4. 删除仓库的 `keyboard-remap/profiles.json`

**需要找到读取 profiles.json 的脚本**：
- 搜索 `grep -r "profiles.json" ~/development/OMD/bin/ ~/development/OMD/share/bin/ ~/development/OMD/quickshell/`
- 可能涉及 `share/bin/omarchy-keyboard-apply`、`share/bin/omarchy-keyboard-render`、`quickshell/services/KeyboardRemap.qml`

**修改模式**（参考 `omd-input-method` 的 `load_schemas()`）：
```python
def profiles_path():
    user = os.path.join(config_home(), "keyboard-remap", "profiles.json")
    if os.path.isfile(user):
        return user
    return os.path.join(omd_root(), "defaults", "config", "keyboard-remap", "profiles.json")
```

### 任务 2.3：迁移 `keyd.generated.conf` 到 state 目录

**现状**：`keyboard-remap/keyd.generated.conf` 是生成产物，应在 state 目录。

**操作**：
1. 搜索生成 keyd.generated.conf 的脚本
2. 改为写入 `~/.local/state/sumika-shell/keyboard-remap/keyd.generated.conf`
3. 如果有 systemd unit 或其他引用指向仓库路径，一并修改
4. 删除仓库的 `keyboard-remap/keyd.generated.conf`
5. 在 `.gitignore` 中如有相关规则也更新

**验证**：
- `python3 -c "import json; json.load(open('defaults/config/keyboard-remap/profiles.json'))"`
- `ls ~/.config/sumika-shell/keyboard-remap/profiles.json` 存在
- `ls ~/development/OMD/keyboard-remap/` 不应含 profiles.json（空模板在 defaults/ 下）

### 提交
```
keyboard: migrate jp layout and keyd profiles to user config

- Move hypr/input.lua (jp layout) to ~/.config/sumika-shell/hypr/input.lua
- Move keyboard-remap/profiles.json to user config, add empty template
- Move keyd.generated.conf to state directory
- Update loaders to read from SUMIKA_SHELL_CONFIG_HOME with repo fallback
```

---

## Phase 3：默认应用中立化

### 目标
`defaults/config/quickshell/config.json` 和 `Config.qml` 的 `apps` 节当前硬编码 KDE/fish/pacman 专用命令。改为桌面中立默认，KDE/fish 版本移到用户覆盖。

### 任务 3.1：中立化 `apps` 默认值

**现状**（`defaults/config/quickshell/config.json` 的 `apps` 节）：
```json
{
  "apps": {
    "bluetooth": "kcmshell6 kcm_bluetooth",
    "changePassword": "kitty -1 --hold=yes fish -i -c 'passwd'",
    "manageUser": "kcmshell6 kcm_users",
    "network": "kcmshell6 kcm_networkmanagement",
    "networkEthernet": "kcmshell6 kcm_networkmanagement",
    "taskManager": "plasma-systemmonitor --page-name Processes",
    "terminal": "kitty -1",
    "update": "kitty -1 --hold=yes fish -i -c 'pkexec pacman -Syu'",
    "volumeMixer": "pavucontrol-qt"
  }
}
```

**改为**（桌面中立）：
```json
{
  "apps": {
    "bluetooth": "",
    "changePassword": "",
    "manageUser": "",
    "network": "",
    "networkEthernet": "",
    "taskManager": "",
    "terminal": "xdg-terminal-exec",
    "update": "",
    "volumeMixer": ""
  }
}
```

同时更新 `quickshell/modules/common/Config.qml` 中对应的 `property JsonObject apps` 默认值，保持一致。

### 任务 3.2：把 KDE/fish 版本写入用户配置

**操作**：
1. 读取 `~/.config/sumika-shell/quickshell/config.json`（如果不存在则创建）
2. 在 `apps` 节填入用户当前的 KDE/fish 命令：

```json
{
  "apps": {
    "bluetooth": "kcmshell6 kcm_bluetooth",
    "changePassword": "kitty -1 --hold=yes fish -i -c 'passwd'",
    "manageUser": "kcmshell6 kcm_users",
    "network": "kcmshell6 kcm_networkmanagement",
    "networkEthernet": "kcmshell6 kcm_networkmanagement",
    "taskManager": "plasma-systemmonitor --page-name Processes",
    "terminal": "kitty -1",
    "update": "kitty -1 --hold=yes fish -i -c 'pkexec pacman -Syu'",
    "volumeMixer": "pavucontrol-qt"
  }
}
```

**注意**：如果用户 config.json 已有 `apps` 节（Phase 1 后可能有），合并而非覆盖。

### 任务 3.3：中立化字体默认值

**现状**（`defaults/config/quickshell/config.json` 的 `appearance.fonts` 节）：
```json
{
  "appearance": {
    "fonts": {
      "expressive": "Cantarell",
      "iconNerd": "JetBrainsMono Nerd Font Mono",
      "main": "Cantarell",
      "monospace": "MesloLGS Nerd Font Mono",
      "numbers": "Cantarell",
      "reading": "Cantarell",
      "title": "Cantarell"
    }
  }
}
```

**改为**（`Cantarell` 是 GNOME 默认字体，非通用）：
```json
{
  "appearance": {
    "fonts": {
      "expressive": "Sans Serif",
      "iconNerd": "JetBrainsMono Nerd Font Mono",
      "main": "Sans Serif",
      "monospace": "DejaVu Sans Mono",
      "numbers": "Sans Serif",
      "reading": "Sans Serif",
      "title": "Sans Serif"
    }
  }
}
```

同时更新 `Config.qml` 中 `appearance.fonts` 的 JsonObject 默认值。

把 `Cantarell` 版本写入用户配置 `~/.config/sumika-shell/quickshell/config.json` 的 `appearance.fonts`。

### 验证
- `python3 -c "import json; json.load(open('defaults/config/quickshell/config.json'))"`
- `timeout 8 qs -p apps/omd-bar 2>&1 | grep -E "ERROR|Loaded"` → Configuration Loaded
- `timeout 8 qs -p apps/omd-overview 2>&1 | grep -E "ERROR|Loaded"` → Configuration Loaded

### 提交
```
apps: neutralize default apps and fonts, move KDE/fish to user config

- defaults/config/quickshell/config.json: apps.* and fonts.* changed to
  desktop-neutral defaults (empty strings, xdg-terminal-exec, Sans Serif)
- Config.qml: matching JsonObject defaults updated
- User config: KDE/fish/pacman and Cantarell moved to
  ~/.config/sumika-shell/quickshell/config.json
```

---

## Phase 4：个人 Launchers 迁移

### 目标
`launchers/` 目录含个人应用（WeChat、WPS、KeePassXC、远程桌面），移到用户配置。

### 现状
```
launchers/
├── README.md
├── remote-desktop.desktop
├── wechat.desktop
├── wps.desktop
├── keepassxc.desktop
└── icons/
    ├── wps.png
    ├── keepassxc.png
    ├── wechat.png
    └── remote-desktop.png
```

`.desktop` 文件内容已指向 `$HOME/.config/sumika-shell/scripts/` 和 `$HOME/.config/sumika-shell/launchers/icons/`，但文件本身还在仓库——半迁移状态。

### 操作

1. **复制到用户配置**：
```bash
mkdir -p ~/.config/sumika-shell/launchers/icons
cp ~/development/OMD/launchers/*.desktop ~/.config/sumika-shell/launchers/
cp ~/development/OMD/launchers/icons/*.png ~/.config/sumika-shell/launchers/icons/
cp ~/development/OMD/launchers/README.md ~/.config/sumika-shell/launchers/
```

2. **在仓库创建默认模板**：`defaults/launchers/README.md`：
```markdown
# Launchers

Personal application launchers (`.desktop` files and icons) live in:
  ~/.config/sumika-shell/launchers/

The Quickshell app launcher reads from the standard XDG application
directories. Place your personal `.desktop` files there.
```

3. **搜索引用 `launchers/` 的代码**：
```bash
grep -r "launchers" ~/development/OMD/bin/ ~/development/OMD/quickshell/ ~/development/OMD/share/
```
如果有脚本从仓库 `launchers/` 目录读取，改为从用户配置读取或从标准 XDG 路径读取。

4. **删除仓库的 `launchers/` 目录**：
```bash
rm -rf ~/development/OMD/launchers
```

5. **更新 `.gitignore`** 如果有相关规则。

### 验证
- `ls ~/development/OMD/launchers` → 不存在
- `ls ~/.config/sumika-shell/launchers/` → 含 .desktop 文件和 icons/
- `ls ~/development/OMD/defaults/launchers/README.md` → 存在
- `timeout 8 qs -p apps/omd-applauncher 2>&1 | grep -E "ERROR|Loaded"` → Configuration Loaded

### 提交
```
launchers: move personal .desktop files to user config

- Move launchers/{wechat,wps,keepassxc,remote-desktop}.desktop and
  icons/ to ~/.config/sumika-shell/launchers/
- Add defaults/launchers/README.md with instructions
- Delete repo launchers/ directory
```

---

## Phase 5：杂项

### 任务 5.1：光标主题配置化

**现状**：`hypr/looknfeel.lua:118-120` 硬编码 `Adwaita` 光标。

**操作**：
1. 读取 `hypr/looknfeel.lua` 最后几行（117-121）
2. 改为从配置读取。在 `defaults/config/quickshell/config.json` 新增：
```json
{
  "cursor": {
    "theme": "Adwaita",
    "size": 24
  }
}
```
3. 在 `Config.qml` 加对应 JsonObject
4. `hypr/looknfeel.lua` 改为从环境变量或 Lua 配置读取——但 Hyprland Lua 无法读 QML config.json。替代方案：从 `~/.config/sumika-shell/hypr/looknfeel.lua` 用户覆盖。

**推荐简单方案**：把 3 行光标设置移到 `~/.config/sumika-shell/hypr/looknfeel.lua`，仓库的 `hypr/looknfeel.lua` 删除这 3 行。仓库默认不设光标主题（让 Hyprland 用自己的默认）。

```lua
-- ~/.config/sumika-shell/hypr/looknfeel.lua
hl.env("XCURSOR_THEME", "Adwaita")
hl.env("HYPRCURSOR_THEME", "Adwaita")
o.exec_on_start("hyprctl setcursor Adwaita 24")
```

### 任务 5.2：Waybar 杀进程移到用户配置

**现状**：`hypr/autostart.lua:4-5` 硬编码杀 Waybar。

**操作**：
1. 把这两行移到 `~/.config/sumika-shell/hypr/autostart.lua`
2. 仓库的 `hypr/autostart.lua` 删除这两行

仓库 `hypr/autostart.lua` 改为：
```lua
-- Extra autostart processes.
-- o.launch_on_start("my-service")
local state_home = os.getenv("SUMIKA_SHELL_STATE_HOME") or (os.getenv("XDG_STATE_HOME") or os.getenv("HOME") .. "/.local/state") .. "/sumika-shell"
o.exec_on_start((os.getenv("OMD_ROOT") or "") .. "/bin/omd-restart")
o.exec_on_start((os.getenv("OMD_ROOT") or "") .. "/bin/omd-wallpaper restore")
```

用户 `~/.config/sumika-shell/hypr/autostart.lua` 加入：
```lua
-- Kill Waybar if it's running (personal preference).
o.exec_on_start("mkdir -p " .. paths.state_home .. "/toggles && touch " .. paths.state_home .. "/toggles/waybar-off")
o.exec_on_start("pkill -x waybar || true")
```

注意：用户 autostart.lua 已经有 fcitx5 启动行（Phase 1 加的），把 Waybar 行加在后面。

### 任务 5.3：Windows VM 默认凭据改为空

**现状**：`share/bin/omarchy-windows-vm:143-145` 默认 `USERNAME=docker`、`PASSWORD=admin`。`bin/omd-settings-windows-vm` 也有同样默认值。

**操作**：
1. 搜索 `grep -rn "docker.*admin\|USERNAME.*docker\|PASSWORD.*admin" ~/development/OMD/bin/ ~/development/OMD/share/bin/`
2. 把默认凭据改为空字符串，强制用户输入。或从 `~/.config/sumika-shell/windows-vm.json` 读取。

### 任务 5.4：确认 OCR 语言配置化

**操作**：
1. 搜索 `grep -rn "OCR_LANG\|PaddleOCR\|ocr.*lang\|zh_CH\|chinese" ~/development/OMD/bin/ ~/development/OMD/share/`
2. 如果 OCR 语言硬编码为 `zh`，改为从 `~/.config/sumika-shell/ocr.json` 或 config.json 读取。

### 验证
- `lua -e "loadfile('hypr/looknfeel.lua')"` 无错误
- `timeout 8 qs -p apps/omd-bar 2>&1 | grep -E "ERROR|Loaded"` → Configuration Loaded
- `ls ~/.config/sumika-shell/hypr/looknfeel.lua` 存在且含光标设置
- `ls ~/development/OMD/hypr/looknfeel.lua` 不含光标设置行

### 提交
```
misc: cursor theme, waybar kill, windows vm creds to user config

- Move cursor theme (Adwaita) to ~/.config/sumika-shell/hypr/looknfeel.lua
- Move Waybar kill to user autostart override
- Windows VM default credentials changed to empty
- OCR language verified/configured
```

---

## 完成后的最终检查

1. **工作区干净**：`git status --short` 无未提交改动
2. **全部编译**：
```bash
cd ~/development/OMD
for app in omd-bar omd-overview omd-applauncher omd-clipboard; do
  echo "=== $app ==="
  timeout 8 qs -p apps/$app 2>&1 | grep -E "ERROR|Loaded"
done
```
全部应显示 `Configuration Loaded`。

3. **Lua 语法**：
```bash
lua -e "loadfile('hypr/hyprland.lua')"
lua -e "loadfile('hypr/looknfeel.lua')"
lua -e "loadfile('hypr/bindings.lua')"
lua -e "loadfile('hypr/autostart.lua')"
lua -e "loadfile('hypr/input.lua')"
```
全部无输出（即通过）。

4. **JSON 有效**：
```bash
python3 -c "import json; json.load(open('defaults/config/quickshell/config.json'))"
python3 -c "import json; json.load(open('defaults/config/input-method/schemas.json'))"
python3 -c "import json; json.load(open('defaults/config/keyboard-remap/profiles.json'))" 2>/dev/null || true
```

5. **用户配置存在**：
```bash
ls ~/.config/sumika-shell/hypr/input.lua
ls ~/.config/sumika-shell/hypr/bindings.lua
ls ~/.config/sumika-shell/hypr/autostart.lua
ls ~/.config/sumika-shell/hypr/looknfeel.lua
ls ~/.config/sumika-shell/input-method/schemas.json
ls ~/.config/sumika-shell/keyboard-remap/profiles.json
ls ~/.config/sumika-shell/launchers/
ls ~/.config/sumika-shell/quickshell/config.json
```

6. **仓库不再含个人设置**：
```bash
# 这些应该不存在或为空模板
ls ~/development/OMD/omarchy/fcitx5/ 2>&1 | grep "No such file"
ls ~/development/OMD/launchers/ 2>&1 | grep "No such file"
cat ~/development/OMD/hypr/input.lua  # 应只有注释
grep -c "fcitx5" ~/development/OMD/hypr/default/hypr/autostart.lua  # 应为 0
grep -c "kb_layout.*jp" ~/development/OMD/hypr/input.lua  # 应为 0
```

---

## 重要注意事项

1. **不要创建测试文件**：项目无测试框架，验证靠编译 + 运行。
2. **不要修改 `AGENTS.md`**：它是项目规则文档。
3. **不要动 `docs/archive/`**：那是历史文档。
4. **每个 Phase 单独提交**：便于 review 和回滚。
5. **用户配置文件在 `~/.config/sumika-shell/`**：这些文件不在 git 仓库内，用 `write` 工具直接写。
6. **仓库代码用 `edit` 工具**：不要用 `write` 覆盖整个文件。
7. **先读再改**：每次修改前先 `read` 确认当前内容和行号。
8. **`edit` 工具的 TAG 会过期**：每次 `edit` 后用返回的新 TAG 做下一次编辑。
9. **如果某个文件引用了被移动的文件**：搜索 `grep -r "old_path" ~/development/OMD/` 找到所有引用并更新。
10. **中文注释可以保留**：项目已有中文注释先例。
11. **如果遇到不确定的情况**：在文档中标注 `[需确认]` 并跳过，不要猜测。

## 当前进度

| Phase | 状态 | 提交 |
|---|---|---|
| Phase 1：输入法模块化 | ✅ 已完成 | `65c3637` |
| Phase 2：键盘与 keyd | ⬜ 待执行 | — |
| Phase 3：默认应用中立化 | ⬜ 待执行 | — |
| Phase 4：个人 Launchers | ⬜ 待执行 | — |
| Phase 5：杂项 | ⬜ 待执行 | — |