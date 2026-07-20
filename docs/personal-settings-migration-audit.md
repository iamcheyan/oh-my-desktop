# 个人化设置迁移审计报告

> 日期：2026-07-20
> 范围：`~/development/OMD` 仓库内被硬编码的个人设置
> 目标：抽离到 `~/.config/sumika-shell/` 或做成可开关选项
> 验证：所有发现均通过实际读取文件验证

## 🔴 HIGH 严重度（明确个人化，他人用会出错或不可用）

### 1. 输入法 — Fcitx5 + Rime 硬编码

| 文件 | 行 | 内容 | 问题 |
|---|---|---|---|
| `hypr/default/hypr/autostart.lua:3` | 3 | `o.launch_on_start("fcitx5 --disable notificationitem")` | 强制启动 fcitx5，ibus/无输入法用户不需要 |
| `bin/omd-input-method:10-18` | 10-18 | `FCITX_SERVICE`、`SCHEMAS = {sbzr, sbzr_mix, easy_en, jaroomaji}` | 完全绑定 fcitx5 + Rime 特定 schema（中文/日文） |
| `bin/omd-input-method:64,116` | 64,116 | `fcitx5-remote` 调用 | 不支持 ibus |
| `quickshell/services/InputMethod.qml:27-32` | 27-32 | `schemas: [{sbzr, sbzr_mix, easy_en, jaroomaji}]` | QML 层也硬编码了 Rime schema |
| `quickshell/modules/bar/modules/InputMethodButton.qml` | — | 栏目中的输入法按钮 | 依赖上面的 service |
| `omarchy/fcitx5/conf/notifications.conf` | 1-4 | `# 隐藏通知` 中文注释 | fcitx5 配置文件不应在主仓库 |
| `hypr/bindings.lua:48-52` | 48-52 | `SUPER+SPACE` 绑定到"循环 Rime schemas"（注释明说：only keyboard-us and rime on this setup） | 个人绑定，他人无 Rime 会失效 |

**修法**：详见下方"输入法模块化设计"章节。

---

### 2. 键盘布局 — 日文布局硬编码

| 文件 | 行 | 内容 | 问题 |
|---|---|---|---|
| `hypr/input.lua:7` | 7 | `kb_layout = "jp"` | 默认应为 `us`（`hypr/default/hypr/input.lua:4` 就是 `us`） |
| `hypr/input.lua:12` | 12 | `kb_options = "compose:caps"` | 个人偏好 |
| `hypr/input.lua:6` | 6 | 注释 "Use multiple keyboard layouts and switch between them with Left Alt + Right Alt" | 个人工作流 |

**修法**：`hypr/input.lua` 整个文件移到 `~/.config/sumika-shell/hypr/input.lua`（默认已经是 `us`，个人覆盖为 `jp`）。

---

### 3. keyd 键盘重映射 — 个人设备清单

| 文件 | 行 | 内容 | 问题 |
|---|---|---|---|
| `keyboard-remap/profiles.json:4-56` | 全部 | 5 个个人设备：`apple-spi-keyboard`、`compx-2-4g-receiver`、`guo-magic-keyboard`、`logitech-usb-receiver`、`minila-r-convertible` | 个人外设清单，含个人 preset（`alt-win-swap`、`muhenkan-meta: f13` 等） |
| `keyboard-remap/keyd.generated.conf` | — | 生成产物 | 应在 state 目录而非仓库 |

**修法**：`keyboard-remap/profiles.json` 移到 `~/.config/sumika-shell/keyboard-remap/profiles.json`；`keyd.generated.conf` 移到 `~/.local/state/sumika-shell/keyboard-remap/`。仓库只保留空模板 + 渲染脚本。

---

### 4. 默认应用 — KDE/fish/pacman 特定

`defaults/config/quickshell/config.json` 的 `apps` 节：

| 键 | 值 | 问题 |
|---|---|---|
| `apps.terminal` | `"kitty -1"` | 可接受（项目支持 kitty） |
| `apps.changePassword` | `"kitty -1 --hold=yes fish -i -c 'passwd'"` | 强制 fish shell |
| `apps.update` | `"kitty -1 --hold=yes fish -i -c 'pkexec pacman -Syu'"` | 强制 fish + pacman（Arch 专用） |
| `apps.bluetooth` | `"kcmshell6 kcm_bluetooth"` | KDE 专用 |
| `apps.network` | `"kcmshell6 kcm_networkmanagement"` | KDE 专用 |
| `apps.networkEthernet` | `"kcmshell6 kcm_networkmanagement"` | KDE 专用 |
| `apps.manageUser` | `"kcmshell6 kcm_users"` | KDE 专用 |
| `apps.taskManager` | `"plasma-systemmonitor --page-name Processes"` | KDE 专用 |
| `apps.volumeMixer` | `"pavucontrol-qt"` | Qt 专用 |

**修法**：把 `apps.*` 默认值改为发行版/桌面中立的命令（如 `apps.terminal: "xdg-terminal-exec"`、`apps.update: ""` 留空让用户填），KDE/fish/pacman 版本移到 `~/.config/sumika-shell/quickshell/config.json` 覆盖。

---

### 5. 个人应用 Launchers

| 文件 | 问题 |
|---|---|
| `launchers/wechat.desktop` | WeChat（个人应用） |
| `launchers/wps.desktop` | WPS Office（个人应用） |
| `launchers/keepassxc.desktop` | KeePassXC（个人应用） |
| `launchers/remote-desktop.desktop` | 个人远程桌面 |
| `launchers/icons/{wechat,wps,keepassxc,remote-desktop}.png` | 对应图标 |

注：`.desktop` 文件里 `Exec=$HOME/.config/sumika-shell/scripts/wechat` 已经指向用户配置路径，说明**半迁移状态**——文件本身还在仓库。

**修法**：`launchers/` 整个目录移到 `~/.config/sumika-shell/launchers/`。仓库保留 `defaults/launchers/` 空模板 + README 说明。

---

## 🟡 MEDIUM 严重度（很可能个人化）

### 6. 字体选择

`defaults/config/quickshell/config.json` 的 `appearance.fonts`：

| 键 | 值 | 备注 |
|---|---|---|
| `main` | `"Cantarell"` | GNOME 默认字体，非通用 |
| `numbers` | `"Cantarell"` | 同上 |
| `title` | `"Cantarell"` | 同上 |
| `reading` | `"Cantarell"` | 同上 |
| `expressive` | `"Cantarell"` | 同上 |
| `monospace` | `"MesloLGS Nerd Font Mono"` | 个人偏好 |
| `iconNerd` | `"JetBrainsMono Nerd Font Mono"` | 可接受（nerd font 标准） |

注：`Config.qml` 的默认值是 `MesloLGS Nerd Font Mono`，但 `config.json` 覆盖为 `Cantarell`。

**修法**：`config.json` 默认字体改为更通用的（如 `Sans Serif`/`DejaVu Sans`），`Cantarell` 移到个人覆盖。

---

### 7. 光标主题

| 文件 | 行 | 内容 |
|---|---|---|
| `hypr/looknfeel.lua:118-120` | 118-120 | `hl.env("XCURSOR_THEME", "Adwaita")`、`HYPRCURSOR_THEME=Adwaita`、`hyprctl setcursor Adwaita 24` |

**修法**：Adwaita 是 GNOME 默认，但其他人可能用 Bibata/Phinger。改为从配置读 `cursorTheme`/`cursorSize`，默认 `Adwaita 24` 可保留。

---

### 8. Waybar 杀进程

| 文件 | 行 | 内容 |
|---|---|---|
| `hypr/autostart.lua:4-5` | 4-5 | `mkdir -p toggles && touch waybar-off` + `pkill -x waybar \|\| true` |

个人习惯（防止 Waybar 残留），其他人可能用 Waybar。

**修法**：移到个人 `hypr/autostart.lua` 覆盖，或加 toggle `toggles/kill-waybar`。

---

### 9. OCR 语言

需进一步确认 `bin/omd-ocr`/`omd-settings-ocr` 是否硬编码中文 OCR 语言（scout 搜索到 `OCR_LANG` 引用）。若 PaddleOCR 默认 `zh`，应改为配置选项。

---

### 10. Windows VM 默认凭据

| 文件 | 行 | 内容 |
|---|---|---|
| `share/bin/omarchy-windows-vm:143-145` | 143-145 | 默认 `USERNAME=docker`、`PASSWORD=admin` |
| `bin/omd-settings-windows-vm` | 322,402,493 | 同样默认值 |

**修法**：默认凭据应留空强制用户输入，或从 `~/.config/sumika-shell/windows-vm.json` 读。

---

## 🟢 LOW 严重度（边界/可保留）

### 11. 仓库内 fcitx5 配置目录

`omarchy/fcitx5/conf/notifications.conf` 仅 4 行注释，价值低。整个 `omarchy/` 目录命名遗留（AGENTS.md 说 `omd` 前缀 rename deferred）。

### 12. Hyprland 窗口规则

`hypr/looknfeel.lua:30-66` 的窗口规则都是为项目自己的 TUI/设置应用（`org.omd.*`、`org.omarchy.*`），**这些是项目自带应用，应保留**。未见为外部个人应用（Spotify/Obsidian 等）写的规则——这部分干净。

### 13. monitors.lua

`hypr/monitors.lua` 已正确从 `~/.local/state/sumika-shell/display/layout.lua` 读取保存的布局，未硬编码显示器名——**这部分干净**。

### 14. 通知静音列表

`notifications/muted_apps.cfg` 当前为空（0 行），无问题。`share/bin/omarchy-edit-muted-apps` 编辑的是用户配置路径——设计正确。

---

## 优先级迁移计划

### Phase 1：输入法模块化（最高优先）
1. 把 `fcitx5` 自启从 `default/hypr/autostart.lua` 移到个人 `hypr/autostart.lua`
2. `omd-input-method` 增加 ibus 后端检测 + schema 列表外部化到 `~/.config/sumika-shell/input-method/schemas.json`
3. `InputMethod.qml` 的 `schemas` 改为运行时从配置读，空则隐藏 bar 按钮
4. `omarchy/fcitx5/` 移到 `~/.config/sumika-shell/fcitx5/`
5. `SUPER+SPACE` 绑定移到个人 `hypr/bindings.lua`

### Phase 2：键盘与 keyd
1. `hypr/input.lua`（jp 布局）移到 `~/.config/sumika-shell/hypr/input.lua`
2. `keyboard-remap/profiles.json` 移到用户配置
3. `keyboard-remap/keyd.generated.conf` 移到 state 目录

### Phase 3：默认应用中立化
1. `defaults/config/quickshell/config.json` 的 `apps.*` 改为桌面中立默认（`xdg-terminal-exec`、空字符串）
2. KDE/fish/pacman 版本移到个人 `quickshell/config.json` 覆盖
3. 字体默认改为通用值

### Phase 4：个人 launchers
1. `launchers/` 移到 `~/.config/sumika-shell/launchers/`
2. 仓库保留 `defaults/launchers/README.md` 说明

### Phase 5：杂项
1. 光标主题改为配置驱动
2. Waybar 杀进程加 toggle
3. Windows VM 默认凭据改为空
4. 确认 OCR 语言是否需配置化

---

## 已迁移好的部分（无需动）

- `monitors.lua` — 已从 state 目录读布局 ✓
- `notifications/muted_apps.cfg` — 已指向用户配置 ✓
- 窗口规则 — 都是为项目自带应用 ✓
- 主题/wallpaper — 已通过 state 目录生成 ✓
- `.desktop` 文件的 `Exec`/`Icon` 路径 — 已指向 `~/.config/sumika-shell/` ✓（但文件本身还在仓库，见 Phase 4）

---

# 输入法模块化设计

## 目标

- 不使用输入法的用户：默认关闭，bar 上不显示按钮，不启动任何 IM 进程
- Fcitx5 用户：保留现有行为，schema 列表可个人化
- Ibus 用户：未来可扩展（先做架构，不实现）
- 所有个人部分（fcitx5 配置、schema 列表、快捷键）在 `~/.config/sumika-shell/` 下

## 配置开关位置

在 `defaults/config/quickshell/config.json` 增加一节：

```json
{
  "inputMethod": {
    "enabled": false,
    "backend": "auto",
    "autostart": false,
    "switchKey": "SUPER + SPACE",
    "switchSchemaKey": "SUPER + SHIFT + SPACE",
    "schemasFile": "input-method/schemas.json"
  }
}
```

| 字段 | 默认 | 说明 |
|---|---|---|
| `enabled` | `false` | 总开关。`false` 时 bar 不显示按钮、不启动 IM、不绑定快捷键 |
| `backend` | `"auto"` | `"auto"` 自动检测 / `"fcitx5"` / `"ibus"` / `"none"` |
| `autostart` | `false` | 是否在 `default/hypr/autostart.lua` 里启动 IM 进程 |
| `switchKey` | `"SUPER + SPACE"` | 切换输入法的 Hyprland 键绑定（空字符串=不绑定） |
| `switchSchemaKey` | `"SUPER + SHIFT + SPACE"` | 切换 schema 的键绑定 |
| `schemasFile` | `"input-method/schemas.json"` | 相对 `~/.config/sumika-shell/` 的 schema 列表路径 |

**为什么放 `config.json` 而不是单独文件**：
- 项目已有 `Config.qml` 单例 + JsonAdapter 机制，统一管理
- `omd-settings-tui` 已有 quickshell 配置编辑入口，加一个 toggle 不需新 TUI
- 用户覆盖路径 `~/.config/sumika-shell/quickshell/config.json` 天然支持

## Schema 列表外部化

### 现状（硬编码）

`bin/omd-input-method:14-18`：
```python
SCHEMAS = {
    "sbzr": {"language": "zh", "name": "Chinese", "variant": "Natural"},
    "sbzr_mix": {"language": "zh", "name": "Chinese", "variant": "Mixed"},
    "easy_en": {"language": "en", "name": "English", "variant": "Easy English"},
    "jaroomaji": {"language": "ja", "name": "Japanese", "variant": "Romaji"},
}
```

`quickshell/services/InputMethod.qml:27-32`：
```qml
readonly property var schemas: [
    { id: "sbzr", badge: "中", title: "Chinese", variant: "Natural input" },
    ...
]
```

### 改造后

**文件**：`~/.config/sumika-shell/input-method/schemas.json`

```json
{
  "backend": "fcitx5",
  "schemas": [
    {
      "id": "sbzr",
      "language": "zh",
      "name": "Chinese",
      "variant": "Natural input",
      "badge": "中"
    },
    {
      "id": "sbzr_mix",
      "language": "zh",
      "name": "Chinese",
      "variant": "Mixed input",
      "badge": "混"
    },
    {
      "id": "easy_en",
      "language": "en",
      "name": "English",
      "variant": "Easy English",
      "badge": "A"
    },
    {
      "id": "jaroomaji",
      "language": "ja",
      "name": "Japanese",
      "variant": "Romaji",
      "badge": "あ"
    }
  ]
}
```

**仓库默认模板**：`defaults/config/input-method/schemas.json`（空 schemas 数组）

### 加载链路

```
~/.config/sumika-shell/input-method/schemas.json   ← 用户（chezmoi）
        ↓ (不存在时 fallback)
defaults/config/input-method/schemas.json           ← 仓库默认（空）
```

`omd-input-method` 启动时读 `SUMIKA_SHELL_CONFIG_HOME/input-method/schemas.json`，没有则 `schemas=[]`。

`InputMethod.qml` 通过 `Process` 调用 `omd-input-method schemas` 子命令拿到 JSON，赋给 `root.schemas`。**不再在 QML 里硬编码**。

## 后端检测

`omd-input-method` 增加 `backend` 子命令：

```python
def detect_backend():
    """检测可用 IM 后端，返回 'fcitx5' / 'ibus' / '' """
    if shutil.which("fcitx5-remote"):
        return "fcitx5"
    if shutil.which("ibus"):
        return "ibus"
    return ""

# status() 里加 backend 字段
{
    "available": bool(input_method),
    "backend": detect_backend(),
    "inputMethod": input_method,
    "schemas": load_schemas(),  # 从外部 JSON 读
    ...
}
```

`InputMethod.qml` 根据 `data.backend` 走不同分支：
- `fcitx5` → 现有 Rime 路径
- `ibus` → 未来扩展（先返回 not implemented）
- 空 → `available=false`，按钮隐藏

## Bar 按钮显隐

`InputMethodButton.qml` 改为：

```qml
visible: Config.options.inputMethod.enabled && InputMethod.available
```

- `enabled=false` → 总开关关，按钮永不显示
- `enabled=true` 但 `available=false`（无后端）→ 也不显示

## Autostart 模块化

### 现状

`hypr/default/hypr/autostart.lua:3`：
```lua
o.launch_on_start("fcitx5 --disable notificationitem")
```

**问题**：这是 default 层，所有人都启动 fcitx5。

### 改造

**default 层**改为条件启动：

```lua
-- hypr/default/hypr/autostart.lua
-- Input method autostart — only if user enables it in config.
local config_home = os.getenv("SUMIKA_SHELL_CONFIG_HOME")
    or (os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "/sumika-shell"
local im_config_file = io.open(config_home .. "/quickshell/config.json", "r")
local im_autostart = false
if im_config_file then
    local content = im_config_file:read("*a")
    im_config_file:close()
    -- 简单字符串匹配，避免引入 JSON 解析依赖
    im_autostart = content:match('"inputMethod"%s*:%s*{%s*"autostart"%s*:%s*(true)') ~= nil
end
if im_autostart then
    local backend = "fcitx5"  -- 默认
    -- 可从 schemas.json 读 backend 字段
    o.launch_on_start(backend .. " --disable notificationitem")
end
```

**更简单的方案**：把 `fcitx5` 启动**整个移出 default**，放到用户的 `hypr/autostart.lua`（已经有个人覆盖文件）：

```lua
-- ~/.config/sumika-shell/hypr/autostart.lua（用户个人覆盖）
o.launch_on_start("fcitx5 --disable notificationitem")
```

仓库的 `hypr/default/hypr/autostart.lua` **不再启动任何 IM**。

**推荐这个方案**——最干净，符合项目"个人设置在 `~/.config/sumika-shell/`"的架构。`config.json` 的 `inputMethod.autostart` 字段可以作为 TUI 里显示用的元数据，实际启动由用户 `hypr/autostart.lua` 控制。

## 快捷键绑定

### 现状

`hypr/bindings.lua:48-52`（个人覆盖层）：
```lua
hl.unbind("SUPER + SPACE")
hl.unbind("SUPER + SHIFT + SPACE")
hl.unbind("SUPER + CTRL + SPACE")
-- 循环 Rime schemas
```

**问题**：这是个人覆盖层 `hypr/bindings.lua`（不是 default），理论上已经是个人文件。但它在仓库里。

### 改造

**default 层**（`hypr/default/hypr/bindings/`）不绑定 SUPER+SPACE——保持干净。

**个人层** `hypr/bindings.lua` 里的 Rime 绑定**移到** `~/.config/sumika-shell/hypr/bindings.lua`（或保留在仓库的 `hypr/bindings.lua` 但加 config 守卫）。

**推荐**：移到用户配置。仓库的 `hypr/bindings.lua` 改为只放通用绑定（窗口导航、启动器等），IM 绑定完全外移。

## 文件迁移清单

| 现位置 | 目标位置 | 说明 |
|---|---|---|
| `omarchy/fcitx5/conf/notifications.conf` | `~/.config/sumika-shell/fcitx5/conf/notifications.conf` | fcitx5 配置 |
| `keyboard-remap/profiles.json`（IM 相关部分） | `~/.config/sumika-shell/input-method/schemas.json` | schema 列表 |
| `hypr/bindings.lua:48-52` Rime 绑定 | `~/.config/sumika-shell/hypr/bindings.lua` | 个人快捷键 |
| `hypr/default/hypr/autostart.lua:3` fcitx5 启动 | `~/.config/sumika-shell/hypr/autostart.lua` | 个人自启 |

## 代码改动清单

### `bin/omd-input-method`

1. 删除硬编码 `SCHEMAS` dict
2. 增加 `load_schemas()` 从 `SUMIKA_SHELL_CONFIG_HOME/input-method/schemas.json` 读
3. 增加 `detect_backend()` 检测 fcitx5/ibus
4. `status` 输出增加 `backend` 和 `schemas` 字段
5. 增加 `schemas` 子命令打印 schema JSON

### `quickshell/services/InputMethod.qml`

1. 删除 `readonly property var schemas: [...]` 硬编码
2. 改为 `property var schemas: []`，从 `omd-input-method status` 输出填充
3. `available` 改为同时要求 `Config.options.inputMethod.enabled && data.available`

### `quickshell/modules/bar/modules/InputMethodButton.qml`

1. `visible` 改为 `Config.options.inputMethod.enabled && InputMethod.available`

### `defaults/config/quickshell/config.json`

1. 增加 `inputMethod` 节（enabled=false, backend=auto 等）

### `quickshell/modules/common/Config.qml`

1. 增加 `JsonObject inputMethod` 默认值

### `hypr/default/hypr/autostart.lua`

1. 删除 `fcitx5` 启动行

## 验证方法

1. **默认关闭**：清空 `~/.config/sumika-shell/quickshell/config.json` 的 `inputMethod` 节，`omd-restart` 后 bar 上无 IM 按钮，无 fcitx5 进程
2. **fcitx5 开启**：在用户 config 设 `inputMethod.enabled=true` + `~/.config/sumika-shell/hypr/autostart.lua` 启动 fcitx5 + `schemas.json` 填 schema，`omd-restart` 后 bar 显示按钮，SUPER+SPACE 切换
3. **无后端**：`enabled=true` 但系统无 fcitx5/ibus，按钮不显示（available=false）
4. **schema 空**：`schemas.json` 的 `schemas: []`，按钮显示但点开无选项

## 未来扩展

- ibus 后端：在 `omd-input-method` 增加 ibus 调用分支（`ibus engine` 命令）
- 多 IM 切换：`backend: "fcitx5"` 时不仅切换 Rime schema，还能切换 fcitx5 内的 IM（keyboard-us ↔ rime）
- per-window schema：已有 `queuedWindowAddress` 机制，保留