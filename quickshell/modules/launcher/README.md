# Launcher — Application Launcher

Sumika Shell 的应用启动器，提供 "Applications" 工具栏按钮和全屏 app 网格界面。

## 目录结构

```
launcher/
├── module.json               # 模块声明
├── module-actions.qml        # 注册 app-launcher.toggle/open/close 到 ActionManager
├── AppLauncherButton.qml     # 工具栏按钮 (BarTextButton "Applications")
├── shell.qml                 # Quickshell 入口
├── internal-tools.json       # 内置工具清单
├── bin/
│   ├── omd-applauncher       # CLI
│   └── omd-applauncher-cache # 桌面应用缓存构建脚本
├── modules/appLauncher/
│   ├── AppLauncher.qml       # 主界面 UI (网格 + 搜索)
│   ├── RunningApps.qml       # 运行中的应用检测
│   └── widgets/              # 专用 widgets
└── .state/
    └── pinned-apps           # 已固定应用列表 (运行时)
```

## 用法

### 打开启动器

- 点击工具栏 **"Applications"**
- 键盘绑定 `Super+Space`（由 omd-action 转发到 `app-launcher.toggle`）
- IPC: `qs -p apps/omd-bar ipc call action call 'app-launcher.toggle' ''`

### 搜索

即时过滤。匹配字段：name, id, exec, genericName, comment, keywords。

### 固定在顶部

悬停 app 图标右上角的图钉，或右键 pin 区域点击。

### 内置工具

参见 `internal-tools.json`。每个条目以 Nerd Font 图标显示在网格中，点击直接执行 `command`，不走 `gtk-launch`。

## internal-tools.json 格式

```json
[
  {
    "id": "sumika-xxx.desktop",
    "name": "显示名称",
    "description": "描述文字（显示在底部描述区）",
    "command": ["/path/to/binary", "arg1", "arg2"],
    "icon": "wrench",
    "keywords": ["tag1", "tag2"]
  }
]
```

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | string | 唯一标识，建议 `sumika-<name>.desktop` |
| `name` | string | 网格中显示的名称 |
| `description` | string | 底部描述（可选） |
| `command` | string[] | 完整 argv，不会经过 shell 展开 |
| `icon` | string | `NerdIconMap` 中的属性名，如 `keyboard`, `wrench`, `cog`, `terminal`, `settings` |
| `keywords` | string[] | 搜索关键词（可选） |

## 架构要点

- App 来源分两个：
  1. **桌面应用** — `omd-applauncher-cache` 扫描 `.desktop` 文件生成的 JSON 缓存
  2. **内置工具** — `internal-tools.json` 中声明的本机工具
- 两者合并后按 "已固定优先 + 名称排序" 显示
- 内置工具使用 `Quickshell.execDetached(command)` 直接启动；桌面应用走 `gtk-launch` / `gio launch`
- `command` 支持变量替换：`$root` → 仓库根目录 (`Directories.root`)，`$HOME` → 用户 home 目录
- 内置工具图标用 Nerd Font（`NerdIconMap[icon]`），桌面应用图标用系统 IconTheme
- 搜索框获得焦点时弹出虚拟键盘
