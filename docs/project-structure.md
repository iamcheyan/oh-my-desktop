# Sumika Shell (oh-my-desktop) 项目目录结构

> 本文档面向项目维护者，详尽描述 `~/development/OMD` 仓库每个目录的职责、关键文件、代码组织方式。
> 更新日期：2026-07-20

---

## 顶层概览

```
~/development/OMD/
├── AGENTS.md            # 项目规则文档（必读）
├── README.md            # 简介
├── Init.sh              # 51KB 安装脚本（依赖、symlink、session 注册）
├── .gitignore
├── apps/                # 8 个 Quickshell 独立进程入口（~3K LOC）
├── bin/                 # 95 个 omd-* 可执行脚本（~1.2K LOC）
├── config/              # 遗留 nvim 配置
├── current/             # 当前主题/壁纸快照（gitignored，运行时生成）
├── defaults/            # 配置基线模板（所有人共用的默认值）
├── docs/                # 90 篇设计/迁移文档
├── file-share-backup/   # SMB 备份配置（gitignored）
├── hypr/                # Hyprland Lua 配置（~1.3K LOC）
├── icons/               # OS 图标
├── lib/                 # 共享 shell 库（paths.sh）
├── notifications/       # 通知静音列表
├── quickshell/          # QML 共享代码库（45K LOC，项目主体）
├── scripts/             # 辅助脚本（键盘捕获、语音、迁移等）
├── share/               # 共享资源：bin/ themes/ applications/ polkit-1/
└── tests/               # Python TUI 测试
```

### 代码量分布

| 目录 | LOC | 主要语言 |
|------|-----|----------|
| `quickshell/` | ~45,000 | QML |
| `hypr/` | ~1,300 | Lua |
| `bin/` | ~1,200 | Shell/Python |
| `apps/` | ~3,150 | QML |
| `scripts/` | ~660 | Shell/Python |
| `share/bin/` | ~470 | Shell |
| `defaults/` | ~250 | JSON |

### 三层路径模型

| 角色 | 路径 | 管理方 |
|------|------|--------|
| 代码 + QML + 资源 | `~/development/OMD/` | git |
| 用户配置（覆盖、launchers、键盘、通知） | `~/.config/sumika-shell/` | chezmoi |
| 运行时状态（主题、壁纸、keyd 生成配置） | `~/.local/state/sumika-shell/` | 生成，不提交 |

**运行时 symlink**：
- `~/.config/quickshell` → `~/development/OMD/quickshell`
- `~/.config/omd` → `~/development/OMD`

---

## 1. `quickshell/` — QML 共享代码库（项目主体）

这是整个桌面环境的 UI 核心，约 45K LOC QML。所有 Quickshell 进程通过 `qs.` 前缀导入这里的共享模块。

### 顶层结构

```
quickshell/
├── GlobalStates.qml          # 全局状态单例（所有模块共享的状态总线）
├── clipboard_settings.conf   # 剪贴板字体缩放设置
├── .qmlformat.ini            # QML 格式化配置
├── modules/                  # UI 模块集合（10 个子模块）
├── services/                 # 30+ QML singleton 后端服务
├── translations/             # 16 种语言国际化文件
├── scripts/                  # 辅助脚本（色彩、录像、钥匙圈）
├── assets/                   # 静态资源（SVG 图标）
└── docs/                     # quickshell 内部设计文档
```

### 模块导入约定

- `qs` → `quickshell/` 根
- `qs.services` → `quickshell/services/`
- `qs.modules.common` → `quickshell/modules/common/`
- `qs.modules.common.widgets` → `quickshell/modules/common/widgets/`
- `qs.modules.bar` → `quickshell/modules/bar/`

### 1.1 `modules/common/` — 共享基础设施层

**这是整个项目的核心共享层，所有进程都能导入。**

| 文件/目录 | 职责 |
|-----------|------|
| `Config.qml` | **配置单例** — 基于 JSON 的配置系统，监听文件变化自动重载。含所有配置默认值（70+ 项） |
| `Appearance.qml` | **外观主题单例** — Material You 色彩系统、动画参数、圆角半径、字体尺寸、间距 |
| `TuiStyle.qml` | **TUI 风格调色板** — bg/panel/fg/dim/line/accent 等语义色 |
| `Directories.qml` | **路径单例** — XDG 目录 + 项目特定路径 |
| `Persistent.qml` | **持久化状态** — 基于 JSON 的状态持久化 |

**`common/widgets/`（45+ 共享 UI 组件）：**

- **基础**：`StyledText`, `StyledScrollBar`, `StyledFlickable`, `StyledListView`, `StyledImage`, `StyledToolTip`, `StyledProgressBar`, `StyledRadioButton`
- **TUI 风格**：`TuiShell`, `TuiMeterBar`, `TuiActionButton`, `TuiDetailRow`
- **对话框**：`WindowDialog`, `WindowDialogTitle`, `WindowDialogParagraph`, `WindowDialogToolbar`, `FullscreenPolkitWindow`
- **图标**：`NerdIcon`, `NerdIconMap`（10KB 映射表）, `MaterialSymbol`, `CosmicIcon`
- **通知**：`NotificationItem`, `NotificationGroup`, `NotificationAppIcon`, `NotificationListView`
- **导航**：`Toolbar`, `ToolbarTabBar`, `ToolbarTabButton`, `Revealer`, `DragManager`
- **其他**：`RippleButton`, `FloatingActionButton`, `MaterialTextField`, `WavyLine`, `DashedBorder`, `ErrorShakeAnimation`

**`common/functions/`（纯逻辑函数）：**
- `StringUtils.qml`（9.6KB）— 字符串工具
- `ColorUtils.qml`（6KB）— 颜色变换
- `Fuzzy.qml` + `fuzzysort.js` — 模糊搜索
- `WorkspaceNavigation.qml` — 工作区导航
- `NotificationUtils.qml`, `FileUtils.qml`, `WheelUtils.qml`, `Session.qml`
- `OverviewSwitchingController.qml` — 概览切换控制

**`common/panels/lock/`** — 锁屏面板：`LockScreen.qml`, `LockContext.qml`（PAM 认证）, `pam/`

### 1.2 `modules/bar/` — 顶栏模块

| 文件 | 职责 |
|------|------|
| `Bar.qml`（8.6KB） | **主入口** — 为每个显示器创建 PanelWindow，支持上下位置、IPC toggle |
| `BarContent.qml` | 顶栏内容 — 左（启动器+工作区+活动窗口）、中（预留）、右（音频/WiFi/显示/剪贴板/工具/会话） |
| `BarStatusPopup.qml`（120KB） | **弹窗容器** — 所有右侧弹出面板，项目中最大的文件 |
| `Workspaces.qml` | 工作区指示器 |
| `ActiveWindow.qml` | 活动窗口标题 + OS 图标 |
| `SysTray.qml` 系列 | 系统托盘（StatusNotifierItem） |
| `PowerContextMenu.qml` | 电源菜单（注销/重启/关机） |
| `SessionConfirmOverlay.qml` | 会话确认覆盖层 |

**`bar/modules/` — 右侧按钮：**
`AudioButton`, `WifiButton`, `DisplayButton`, `ClipboardButton`, `InputMethodButton`, `ToolsButton`, `SessionButton`, `ScreenshotContextMenu`

### 1.3 `modules/overview/` — 工作区概览

| 文件 | 职责 |
|------|------|
| `Overview.qml`（20.9KB） | **主入口** — 全屏网格，键盘导航、MRU 追踪、搜索模式 |
| `OverviewWidget.qml`（44.4KB） | **窗口预览部件** — 缩略图、图标、跨显示器坐标映射 |
| `OverviewWindow.qml` | 单窗口坐标/尺寸管理 |
| `OverviewSearch.qml`（18.5KB） | 模糊搜索 + 命令模式（`>` 前缀） |

### 1.4 `modules/settings/` — 设置中心

**入口**：`SettingsDialog.qml` — 基于 `WindowDialog` 的设置对话框

**`settings/pages/`（8+ 页）：**
| 页面 | 大小 | 职责 |
|------|------|------|
| `AppearancePage.qml` | 32.5KB | 主题、壁纸、字体 |
| `NetworkPage.qml` | 36.4KB | WiFi 扫描/连接 |
| `BluetoothPage.qml` | 16.9KB | 蓝牙设置 |
| `SoundPage.qml` | 26.0KB | 声音设置 |
| `PowerPage.qml` | 13.2KB | 电源与电池 |
| `SystemPage.qml` | 22.8KB | 自启动、默认应用 |
| `VoicePage.qml` | 31.9KB | 语音输入设置 |
| `KeyboardRemapPage.qml` | 28.7KB | 键盘映射设置 |
| `WindowsVmPage.qml` | 50KB | Windows VM 管理（最大页面） |

**`settings/widgets/`（21 个控件）**：`SettingsNavItem`, `SettingsCard`, `SettingsRow`, `SettingsToggleRow`, `SettingsButton`, `SettingsSlider`, `SettingsDropdownRow`, `SettingsTextFieldRow`, `SettingsSection`, `SettingsDisclosure`, `SettingsOverlayDialog` 等

**`settings/display/`** — 显示器配置子模块：`DisplayPage.qml`, `DisplayConfigState.qml`（23.5KB）, `OutputDetailPane.qml`, `MonitorCanvas.qml`, `MonitorIdentifyOverlay.qml`

**`settings/wallpaper/`** — `WallpaperPickerDialog.qml`（19.3KB）

### 1.5 `modules/regionSelector/` — 截屏/录屏区域选择

| 文件 | 职责 |
|------|------|
| `RegionSelector.qml` | 主入口 — 监听 GlobalStates.regionSelectorOpen |
| `RegionSelection.qml`（35.5KB） | **核心选择器** — 矩形/圆形选区、窗口高亮、测量线、图像搜索 |
| `TargetRegion.qml` | 目标区域识别（窗口/图层/内容） |
| `OptionsToolbar.qml` | 选项工具栏 |

### 1.6 其他 UI 模块

| 模块 | 职责 |
|------|------|
| `modules/lock/` | 锁屏界面（`LockSurface.qml` 17.4KB — 壁纸+毛玻璃+密码+电源） |
| `modules/onScreenDisplay/` | OSD 指示器（音量/亮度/色温/输入法） |
| `modules/notificationPopup/` | 通知弹窗 |
| `modules/schedulePopup/` | 通知历史中心（`TuiNotificationList.qml` 22.2KB） |
| `modules/polkit/` | PolKit 授权对话框 |

### 1.7 `services/` — 后端服务（30+ QML Singleton）

所有服务通过 `import qs.services` 导入。

| 服务 | 大小 | 职责 |
|------|------|------|
| `Audio.qml` | 22KB | **音频** — PipeWire sink/source、设备切换、音量保护 |
| `Network.qml` | 37KB | **网络** — nmcli WiFi/以太网管理（最大服务） |
| `Notifications.qml` | 17.5KB | **通知** — 持久化、分组、超时、静音 |
| `HyprlandData.qml` | 19KB | **Hyprland 数据** — 窗口/工作区/显示器列表、MRU |
| `KeyboardRemap.qml` | 24.7KB | **键盘映射** — keyd 重映射管理 |
| `VoiceInput.qml` | 14KB | **语音输入** — 录音、SenseVoice 转写、粘贴到光标 |
| `Brightness.qml` | 11.4KB | **亮度** — ddcutil/brillo |
| `MprisController.qml` | 5.9KB | 媒体播放控制 |
| `Translation.qml` | 5.2KB | 国际化引擎 |
| `AppSearch.qml` | 6.7KB | Desktop Entry 加载、模糊搜索 |
| `Hyprsunset.qml` | 6KB | 夜间模式色温控制 |
| `InputMethod.qml` | 5KB | fcitx5/ibus 切换 |
| `Battery.qml` | 4.1KB | UPower 电池管理 |
| `KeyringStorage.qml` | 4.2KB | 密钥环存储 |
| `SystemInfo.qml` | 4KB | 发行版/用户名/桌面环境 |
| 其他 | — | `BluetoothStatus`, `DateTime`, `TrayService`, `OmarchyTheme`, `PolkitService`, `Idle`, `Wallpaper`, `TrackArt`, `LockService` 等 |

**子目录**：
- `services/network/WifiAccessPoint.qml` — WiFi 接入点 QML 类型
- `services/hyprlandAntiFlashbangShader/` — 防闪光弹 GLSL 着色器

### 1.8 `translations/` — 国际化

**16 种语言**：en_US（基线 37.3KB）, zh_CN（41.2KB）, de_DE, fr_FR, es_MX, pt_BR, ru_RU（53KB 最大）, ja_JP, it_IT, id_ID, tr_TR, vi_VN, uk_UA, he_HE, ko_KR

**加载机制**：
1. 读取 `translations/<lang>.json`（内置）
2. 读取 `<shellConfig>/translations/<lang>.json`（用户覆盖）
3. 合并后通过 `Translation.tr(key)` 查找

**工具（`translations/tools/`）**：`translation-manager.py`（15KB）, `translation-cleaner.py`（8KB）, `manage-translations.sh`

### 1.9 `scripts/` — 辅助脚本

| 脚本 | 职责 |
|------|------|
| `quickshell` | **主启动脚本** — 设置环境变量、启动 Quickshell 进程 |
| `colors/switchwall.sh`（17.6KB） | 壁纸切换 + 取色 |
| `colors/applycolor.sh` | 应用颜色 |
| `colors/generate_colors_material.py` | Material You 色彩生成 |
| `videos/record.sh` | 屏幕录像（wf-recorder） |
| `images/find_regions.py` | 图片区域查找 |
| `keyring/` | 钥匙圈操作（try_lookup.sh, unlock.sh, is_unlocked.sh） |

### 1.10 `assets/` — 静态资源

- `assets/icons/` — SVG 图标（各发行版图标：arch, fedora, ubuntu, nixos, debian 等）
- `assets/images/` — 图片资源
- `assets/cosmic-icons/` — COSMIC 图标

---

## 2. `hypr/` — Hyprland Lua 配置

### 配置加载链

```
hypr/hyprland.lua
  ├── resolve_root()           # 解析 OMD_ROOT
  ├── require("default.hypr.base")   # 基线加载
  │     ├── envs.lua            # 环境变量
  │     ├── helpers.lua         # 辅助函数
  │     ├── windows.lua         # 窗口规则基线
  │     ├── apps.lua → apps/    # 18 个应用窗口规则
  │     ├── bindings/           # 默认快捷键（clipboard, media, tiling, utilities）
  │     └── toggles/            # 动态开关
  ├── dofile(monitors.lua)      # 显示器布局（每次 reload 重读）
  ├── require("input")          # 输入设备
  ├── require("bindings")       # 快捷键
  ├── require("looknfeel")      # 外观
  ├── require("autostart")      # 自启动
  ├── 用户覆盖层                  # ~/.config/sumika-shell/hypr/*.lua
  │     （input, bindings, looknfeel, autostart）
  ├── require("default.hypr.toggles")  # 开关标志
  └── require("window_rules")   # 窗口规则
```

### 文件清单

| 文件 | 职责 |
|------|------|
| `hyprland.lua` | **主入口** — 加载链、root 解析、用户覆盖加载 |
| `monitors.lua` | 显示器布局（机器相关，每次 reload 重读） |
| `input.lua` | 输入设备（仓库默认：us 布局；个人覆盖在用户配置） |
| `bindings.lua` | 快捷键 |
| `looknfeel.lua` | 外观（窗口规则、浮动窗口、图层模糊） |
| `autostart.lua` | 自启动（omd-restart, omd-wallpaper） |
| `hypridle.conf` | 空闲配置 |
| `hyprsunset.conf` | 夜间模式配置 |
| `xdph.conf` | XDG 门户配置 |
| `.luarc.json` | Lua 语言服务器配置 |

### `hypr/default/hypr/` — 模块化基线

| 文件 | 职责 |
|------|------|
| `base.lua` | 基线加载入口 |
| `paths.lua` | 路径解析（omd_root, config_home, state_home） |
| `envs.lua` | 环境变量设置 |
| `helpers.lua` | 辅助函数 |
| `windows.lua` | 窗口规则基线 |
| `apps.lua` | 应用窗口规则加载器 |
| `require_all.lua` | 批量 require |
| `input.lua` | 默认输入配置 |
| `looknfeel.lua` | 默认外观 |
| `autostart.lua` | 默认自启动 |
| `toggles.lua` | 开关加载器 |

**`apps/`（18 个应用窗口规则）**：`1password`, `bitwarden`, `browser`, `davinci-resolve`, `geforce`, `hyprshot`, `jetbrains`, `localsend`, `moonlight`, `pip`, `qemu`, `retroarch`, `steam`, `system`, `telegram`, `terminals`, `typora`, `webcam-overlay`, `xfreerdp`

**`bindings/`**：`clipboard.lua`, `media.lua`, `tiling-v2.lua`, `utilities.lua`

**`toggles/`**：`flags.lua`, `rounded-corners.conf`, `single-window-aspect-ratio.lua`, `voxtype.lua`, `window-no-gaps.lua`

---

## 3. `apps/` — Quickshell 独立进程入口

8 个独立进程，每个有自己的 `shell.qml` 入口和 `config.json`：

| 进程 | 入口 | 职责 |
|------|------|------|
| `omd-bar` | `shell.qml` | 顶栏、锁屏、OSD、通知弹窗、会话管理 |
| `omd-overview` | `shell.qml` | 工作区概览（窗口预览网格） |
| `omd-applauncher` | `shell.qml` | 应用启动器 |
| `omd-clipboard` | `shell.qml` | 剪贴板管理器（基于 cliphist） |
| `omd-screenshot` | `shell.qml` | 截屏/录屏区域选择 |
| `omd-polkit` | `shell.qml` | PolKit 授权代理 |
| `omd-notification` | `shell.qml` | 通知历史中心 |
| `omd-settings` | `shell.qml` | 设置中心对话框 |

每个 app 目录结构：
```
apps/omd-bar/
├── shell.qml           # 进程入口
├── config.json         # 该进程的 Quickshell 配置
├── GlobalStates.qml    # 进程级全局状态
├── ReloadPopup.qml     # 重载弹窗（部分 app 有）
├── modules/            # 进程专属模块
├── services/           # 进程专属服务
├── scripts/            # 进程专属脚本
├── translations/       # 进程专属翻译
└── assets/             # 进程专属资源
```

**多进程 IPC**：通过 Quickshell 的 `IpcHandler` 通信（Unix socket），每个进程暴露命名 endpoint，如 `screenshot.begin/end`、`voice.toggle`、`menus.close`。

---

## 4. `bin/` — OMD 可执行脚本（95 个）

所有脚本以 `omd-` 前缀命名。按功能分类：

### 4.1 Quickshell 进程启动器
| 脚本 | 职责 |
|------|------|
| `omd-bar` | 启动 bar 进程 |
| `omd-overview` | 启动 overview 进程 |
| `omd-applauncher` | 启动应用启动器（支持 IPC open/close） |
| `omd-clipboard` | 启动剪贴板管理器 |
| `omd-screenshot` | 启动截屏进程 |
| `omd-polkit` | 启动 PolKit 代理 |
| `omd-notification` | 启动通知中心 |
| `omd-restart` | 重启所有 Quickshell 进程 |

### 4.2 设置 TUI（Settings Center 后端）
| 脚本 | 职责 |
|------|------|
| `omd-settings` | 设置中心路由器 |
| `omd-settings-tui` | 通用设置 TUI 入口 |
| `omd-settings-backup-tui` | 备份设置 TUI |
| `omd-settings-keyboard-tui` | 键盘映射设置 TUI |
| `omd-settings-voice-tui` | 语音输入设置 TUI |
| `omd-settings-theme-tui` | 主题设置 TUI |
| `omd-settings-ocr-tui` | OCR 设置 TUI |
| `omd-settings-vm-tui` | VM 设置 TUI |
| `omd-settings-windows-vm` | Windows VM 管理（Docker/QEMU） |
| `omd-settings-keyboard` | 键盘设置后端 |
| `omd-settings-theme` | 主题设置后端 |
| `omd-settings-voice` | 语音设置后端 |
| `omd-settings-ocr` | OCR 设置后端 |
| `omd-launch-settings-*-tui` | 各 TUI 启动器（7 个） |

### 4.3 网络与蓝牙
| 脚本 | 职责 |
|------|------|
| `omd-wifi-tui` | WiFi TUI（nmtui 包装） |
| `omd-bluetooth-tui` | 蓝牙 TUI |
| `omd-bluetooth-connect` | 蓝牙连接 |
| `omd-launch-wifi` | 启动 WiFi 设置 |
| `omd-launch-bluetooth` | 启动蓝牙设置 |
| `omd-network-diag` | 网络诊断 |
| `omd-network-firewall` | 防火墙配置 |
| `omd-network-link-details` | 链路详情 |

### 4.4 显示器与硬件
| 脚本 | 职责 |
|------|------|
| `omd-display-config` | 显示器配置 |
| `omd-brightness-display` | 显示器亮度（ddcutil） |
| `omd-brightness-keyboard` | 键盘背光亮度 |
| `omd-ddc-detect` | DDC 显示器检测 |
| `omd-hw-external-monitors` | 外接显示器 |
| `omd-hyprland-monitor-*` | 显示器操作（internal, mirror, scaling-cycle, watch） |

### 4.5 窗口管理
| 脚本 | 职责 |
|------|------|
| `omd-hyprland-window-close-all` | 关闭所有窗口 |
| `omd-hyprland-window-gaps-toggle` | 窗口间距切换 |
| `omd-hyprland-window-pop` | 窗口弹出 |
| `omd-hyprland-window-transparency-toggle` | 透明度切换 |
| `omd-hyprland-window-single-square-aspect-toggle` | 单窗口宽高比 |
| `omd-hyprland-workspace-layout-toggle` | 工作区布局切换 |

### 4.6 键盘映射（keyd）
| 脚本 | 职责 |
|------|------|
| `omd-keyboard-apply` | 应用 keyd 配置（pkexec 提权） |
| `omd-keyboard-render` | 渲染 keyd 配置 |
| `omd-keyboard-list` | 列出已连接键盘 |
| `omd-keyboard-setup` | 安装 keyd 守护进程 |
| `omd-keyboard-function-row` | Fn 键模式 |

### 4.7 语音输入
| 脚本 | 职责 |
|------|------|
| `omd-voice-record` | 录音 |
| `omd-voice-transcribe` | 语音转写（SenseVoice） |
| `omd-voice-download` | 下载模型 |
| `omd-voice-setup` | 语音环境安装 |
| `omd-edit-voice-bindings` | 编辑语音绑定 |

### 4.8 剪贴板与输入
| 脚本 | 职责 |
|------|------|
| `omd-clipboard` | 剪贴板管理 |
| `omd-clipboard-store` | 存储剪贴板项 |
| `omd-kitty-smart-paste` | Kitty 智能粘贴 |
| `omd-paste-at-cursor` | 在光标处粘贴 |
| `omd-input-method` | 输入法管理 |

### 4.9 应用启动器
| 脚本 | 职责 |
|------|------|
| `omd-launch-terminal` | 启动终端 |
| `omd-launch-terminal-tmux` | 启动 tmux 终端 |
| `omd-launch-browser` | 启动浏览器 |
| `omd-launch-editor` | 启动编辑器 |
| `omd-launch-or-focus` | 启动或聚焦应用 |
| `omd-launch-or-focus-tui` | 启动或聚焦 TUI |
| `omd-launch-or-focus-webapp` | 启动或聚焦 Web 应用 |
| `omd-launch-webapp` | 启动 Web 应用 |
| `omd-launch-tui` | 启动 TUI 工具 |

### 4.10 系统工具
| 脚本 | 职责 |
|------|------|
| `omd-doctor` | 系统诊断 |
| `omd-restart` | 重启 Quickshell |
| `omd-wallpaper` | 壁纸管理 |
| `omd-theme-bg-set` | 主题背景设置 |
| `omd-lock` | 锁屏 |
| `omd-logout` | 注销 |
| `omd-session` | 会话管理 |
| `omd-backup` | 备份 |
| `omd-ocr` | OCR 文字识别（PaddleOCR） |
| `omd-swayosd-client` | SwayOSD 客户端 |
| `omd-detach` | 分离进程 |
| `omd-toggle-touchpad` | 触摸板切换 |
| `omd-powerprofiles-init` | 电源配置初始化 |
| `omd-audio-input-mute` | 麦克风静音 |
| `omd-audio-output-switch` | 音频输出切换 |
| `omd-notification-control` | 通知控制 |
| `omd-applauncher-cache` | 应用启动器缓存 |
| `omd-wake` | 唤醒 |
| `omd-legacy-omarchy` | 遗留 omarchy 兼容层 |
| `omd_tui_shared.py` | TUI 共享 Python 库 |

---

## 5. `share/` — 共享资源

### `share/bin/` — omarchy-* 脚本（40 个）

这些是 `bin/omd-*` 的底层实现（许多 `omd-*` 是 `omarchy-*` 的 symlink 或包装）：

| 分类 | 脚本 |
|------|------|
| 音频 | `omarchy-audio-input-mute`, `omarchy-audio-output-switch` |
| 亮度 | `omarchy-brightness-display`, `omarchy-brightness-keyboard` |
| 显示器 | `omarchy-hw-external-monitors`, `omarchy-hyprland-monitor-*`（5 个） |
| 窗口 | `omarchy-hyprland-window-*`（5 个）, `omarchy-hyprland-workspace-layout-toggle` |
| 键盘 | `omarchy-keyboard-apply`, `omarchy-keyboard-render`, `omarchy-keyboard-list`, `omarchy-keyboard-setup` |
| 启动器 | `omarchy-launch-*`（8 个：terminal, browser, editor, tui, webapp, or-focus 等） |
| 语音 | `omarchy-voice-*`（4 个：record, transcribe, download, setup） |
| 系统 | `omarchy-system-lock`, `omarchy-system-logout`, `omarchy-system-wake`, `omarchy-powerprofiles-init`, `omarchy-toggle-touchpad` |
| 其他 | `omarchy-paste-at-cursor` |

### `share/themes/` — 主题库（22 个主题）

每个主题是一个目录，包含 `colors.toml`（颜色定义）和壁纸：

`catppuccin`, `catppuccin-latte`, `ethereal`, `everforest`, `flexoki-light`, `gruvbox`, `hackerman`, `kanagawa`, `last-horizon`, `lumon`, `matte-black`, `miasma`, `nord`, `oceanblack`, `osaka-jade`, `retro-82`, `ristretto`, `rose-pine`, `solitude`, `tokyo-night`, `vantablack`, `white`

主题切换通过 `share/bin/omarchy-theme-*` 脚本，快照到 `~/.local/state/sumika-shell/theme/current/`。

### `share/applications/` — Desktop 文件

`share/applications/icons/` — 应用图标

### `share/polkit-1/rules.d/` — PolKit 规则

- `50-omd-backup.rules` — 备份提权规则
- `50-omd-keyboard.rules` — keyd 提权规则

### 其他

- `share/version` — 版本标记
- `share/icon.txt`, `share/logo.txt` — ASCII art

---

## 6. `defaults/` — 配置基线模板

所有人共用的默认配置，个人设置在 `~/.config/sumika-shell/` 覆盖：

```
defaults/
├── config/
│   ├── quickshell/config.json       # Quickshell 配置默认值（apps, fonts, bar 等）
│   ├── input-method/schemas.json    # 输入法方案默认模板
│   └── keyboard-remap/profiles.json  # 键盘映射空模板
└── launchers/
    └── README.md                    # 个人启动器说明
```

**加载优先级**：用户配置 > defaults/

---

## 7. 其他顶层目录

### `config/` — 遗留 Neovim 配置
```
config/nvim/lua/plugins/zz-omarchy-theme.lua  # 主题 drop-in
```

### `current/` — 当前主题快照（gitignored）
运行时生成，由主题切换脚本写入：
- `current/theme/` — 当前主题的 colors.toml, foot.ini, ghostty.conf, hyprland.lua 等
- `current/wallpaper.revision` — 壁纸版本
- `current/background` — 当前壁纸

### `lib/` — 共享 Shell 库
- `lib/paths.sh` — 路径解析（SUMIKA_SHELL_CONFIG_HOME, SUMIKA_SHELL_STATE_HOME, SUMIKA_SHELL_ROOT）

### `scripts/` — 辅助脚本
- `flatpak-launch` — Flatpak 启动器
- `key-test`, `key-test-launcher` — 键盘测试
- `key_capture_clipboard.py`, `key_evdev_names.py` — 键盘捕获
- `keyremap-capture`, `keyremap-capture-read` — 键盘映射捕获
- `omd-path.sh` — PATH 设置
- `omd-quickshell-stop.sh` — 停止 Quickshell
- `reload-quickshell`, `reload-terminals` — 重载脚本
- `remote-desktop`, `remote-desktop.conf` — 远程桌面
- `sumika-migrate.sh` — Sumika 迁移脚本
- `voice-bind-tui` — 语音绑定 TUI
- `windows-rdp` — Windows RDP

### `tests/`
- `test_python_tuis.py` — Python TUI 测试

### `notifications/` — 通知静音列表
- `muted_apps.cfg` — 静音通知的应用列表

### `file-share-backup/` — SMB 备份配置（gitignored）
- `config.json` — 备份配置

### `icons/` — OS 图标
- `OS/` — 操作系统图标资源

### `docs/` — 文档（76 篇）
35 活跃文档（`docs/*.md`）
41 归档文档（`docs/archive/`）

**主要分类**：
- **设计**：`settings-layout-system.md`, `keyboard-remap.md`, `omarchy-theme-system.md`
- **审计**：`repo-cleanup-audit-*.md`, `quickshell-cleanup-audit.md`, `dead-code-cleanup.md`
- **架构**：`omd-config-architecture.md`, `deployment-portability.md`
- **功能**：`clipboard-menu.md`, `smart-paste.md`, `overview-command-palette.md`

---

## 8. `Init.sh` — 安装脚本（1502 行）

主要阶段（按函数）：

1. **环境检测**：`detect_distro()` — 识别 arch/debian/rhel/nixos/suse
2. **包管理**：`get_debian_pkg()`, `get_fedora_pkg()`, `get_arch_pkg()` — 包名映射
3. **依赖安装**：`install_packages()`, `install_nixos_system_config()`
4. **Hyprland 源**：`setup_hyprland_repo_debian/rhel()`, `setup_quickshell_repo_rhel()`
5. **字体安装**：`install_user_fonts()` — Nerd Font, Material Symbols, IA Writer
6. **DDC 权限**：`setup_ddcutil_permissions()`
7. **网络蓝牙**：`enable_network_bluetooth_services()`
8. **主安装**：`install_all_dependencies()`
9. **Symlink 创建**：`create_symlinks()`, `repair_runtime_config()`
10. **Session 注册**：`install_session_files()`, `install_nixos_session_files()`
11. **启动器安装**：`install_custom_launchers()` — 从 `~/.config/sumika-shell/launchers/` 复制
12. **Go 工具构建**：`build_go_tools()`
13. **数据迁移**：`migrate_sumika_data()`
14. **主入口**：`main()` — 编排所有阶段

---

## 9. `AGENTS.md` — 项目规则

必读文档，包含：
- 项目命名（Sumika Shell / omd 前缀）
- 数据布局（三层路径模型）
- 运行时 symlink
- Hyprland 加载链
- Quickshell 配置系统
- TUI Terminal Action Pattern
- Path API（环境变量）
- Git 规则
- 编辑规范

---

## 10. 关键架构要点

### 配置系统
1. **基线**：`defaults/config/quickshell/config.json` 提供中性默认值
2. **用户覆盖**：`~/.config/sumika-shell/quickshell/config.json` 覆盖个人设置
3. **热重载**：`Config.qml` 监听文件变化自动重载
4. **持久化**：`Config.qml` 的 `JsonAdapter` 自动写回

### 主题系统（三级）
1. `Appearance.qml` — Material You 色彩系统（从壁纸提取）
2. `TuiStyle.qml` — TUI 风格调色板
3. `OmarchyTheme.qml` — 动态 accent 色

### 服务层
30+ QML 单例服务，覆盖音频、网络、蓝牙、输入法、通知、电源、键盘等所有系统功能。通过 `import qs.services` 导入。

### 多进程架构
8 个独立 Quickshell 进程，通过 `IpcHandler` IPC 通信。每个进程有自己的入口、配置、状态，但共享 `quickshell/` 下的模块和服务。

### 用户配置覆盖机制
Hyprland：`hypr/hyprland.lua` 加载仓库默认 → 加载 `~/.config/sumika-shell/hypr/*.lua` 用户覆盖 → 加载 toggles
Quickshell：`Config.qml` 读取 `defaults/config.json` → 用户 `config.json` 覆盖默认值

### 运行时状态
`~/.local/state/sumika-shell/` 存放生成产物：
- `theme/current/` — 当前主题快照
- `wallpaper/` — 壁纸状态
- `keyboard-remap/keyd.generated.conf` — 生成的 keyd 配置
- `toggles/` — 开关标志

---

## 11. 维护指南

### 修改 UI
- **共享组件**：改 `quickshell/modules/common/widgets/`
- **顶栏**：改 `quickshell/modules/bar/`
- **特定进程**：改 `apps/omd-*/`

### 修改配置默认值
- 改 `defaults/config/quickshell/config.json` + `Config.qml` 的 JsonObject 默认值
- 个人设置在 `~/.config/sumika-shell/` 覆盖

### 修改 Hyprland 配置
- **基线**：改 `hypr/default/hypr/`
- **个人**：改 `~/.config/sumika-shell/hypr/*.lua`
- **应用窗口规则**：`hypr/default/hypr/apps/` 下新建 `.lua` 文件

### 添加新主题
- 在 `share/themes/` 下新建目录，包含 `colors.toml` 和壁纸

### 添加新启动器
- 在 `~/.config/sumika-shell/launchers/` 下添加 `.desktop` 文件和图标
- `Init.sh` 的 `install_custom_launchers()` 会自动安装

### 验证
- **Quickshell 编译**：`timeout 8 qs -p apps/omd-bar 2>&1 | grep -E "ERROR|Loaded"`
- **Lua 语法**：`lua -e "loadfile('hypr/hyprland.lua')"`
- **JSON 有效**：`python3 -c "import json; json.load(open('defaults/config/quickshell/config.json'))"`
- **重载**：`hyprctl reload` + `omd-restart`
- **诊断**：`omd-doctor`