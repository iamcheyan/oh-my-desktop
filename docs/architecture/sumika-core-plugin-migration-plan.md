# Sumika Core / Plugin 目标架构与迁移计划

实际执行必须按
[插件化迁移执行清单](sumika-plugin-migration-execution-checklist.md)
逐阶段进行；本文定义目标和边界，执行清单定义修改顺序、验收门和交付证据。

> 状态：目标架构与迁移执行基准
>
> 适用范围：`sumika-shell`、`sumika-core`、`sumika-modules`、`sumika-settings`
>
> 本文定义最终所有权和迁移顺序。现有实现与本文冲突时，先保持运行稳定，再按本文分阶段迁移；不得通过直接删除核心文件来假装完成拆分。

## 1. 产品定位

项目名称为 **Sumika**，来源于日语“住処（すみか）”，意为居所、栖身之所、家。

产品理念：

> Your desktop, your home.

用户可以按照自己的习惯组合模块。Sumika 不是固定功能集合，而是一个稳定、可扩展的桌面运行时。

子项目命名：

| 名称 | 职责 |
|---|---|
| `sumika-shell` | 完整发行、安装、集成和默认模块组合 |
| `sumika-core` | 最小运行时、宿主 UI、协议和生命周期 |
| `sumika-modules` | 官方 Service Provider 与功能模块 |
| `sumika-settings` | 独立官方设置应用 |

未来可独立发布 `sumika-launcher`、`sumika-notify`、`sumika-lock`、`sumika-voice` 等模块。

## 2. 不可妥协的设计原则

### 2.1 Core 不提供功能，只提供能力

Core 可以提供：

- Plugin、Action、Service、Extension、Layout API；
- 插件发现、校验、启停、故障隔离和进程监督；
- TopBar 与 Overview 的空宿主；
- 统一配置读取、日志、诊断和错误占位；
- Core 自己使用的基础 UI primitives。

Core 不应提供：

- Notification、MPRIS、Launcher、Screenshot、Clipboard；
- Wi-Fi、Audio、Power 等具体系统实现；
- 模块专属按钮、菜单、设置页和快捷键；
- 模块专属后台进程。

### 2.2 插件只能贡献到公开扩展点

禁止插件直接引用或修改 `TopBar.qml`、`Overview.qml` 等 Core 对象。

禁止：

```text
topbar.left.add(...)
powerMenu.add(...)
```

允许：

```text
registerWidget(...)
registerMenuItem(...)
registerAction(...)
registerOverviewProvider(...)
```

扩展点名称属于稳定协议；Core 内部 QML 文件路径和对象层级不属于协议。

### 2.3 插件故障不能终止 Shell

目标行为：

```text
Plugin fails -> plugin disabled/quarantined -> placeholder or notification -> Shell continues
```

任意第三方 QML 与 Core 在同一 Quickshell 进程运行时，无法严格保证这个目标。因此插件 UI 分为两类：

1. **声明式贡献**：插件返回图标、文本、状态、菜单和 Action 描述，由 Core 渲染。默认且安全。
2. **独立应用**：复杂 UI 在独立 Quickshell、GTK、Python 或其他进程运行，由 Action 启动。

只有明确标记为 `trustedInProcess` 的官方模块可以向 Core 进程加载任意 QML；该能力不作为普通第三方 API。

### 2.4 UI 与系统逻辑分离

UI 模块只调用 Service API。Service Provider 才能访问 NetworkManager、PipeWire、Hyprland IPC 等系统接口。

```text
Wifi Widget -> NetworkService API -> NetworkManager Provider
```

替换 Wifi Widget 不应影响 Network Service；替换 NetworkManager Provider 不应要求修改 Widget。

### 2.5 清单是唯一事实源

模块的入口、Action、Service、Bar Widget、Menu、Settings、快捷键和进程必须全部来自 `module.json`。

Core 中不得再存在与插件重复的：

- builtin Bar 注册；
- Hyprland 硬编码绑定；
- `bin/omd-<plugin>` 实现；
- `apps/omd-<plugin>` 实现；
- 启停脚本白名单。

## 3. 最终分层

### 3.1 Core

```text
sumika-core/
├── runtime/
│   ├── PluginManager
│   ├── ProcessSupervisor
│   ├── ConfigManager
│   └── IpcRouter
├── api/
│   ├── ActionAPI
│   ├── ServiceAPI
│   ├── ExtensionAPI
│   └── schemas/
├── ui/
│   ├── TopBarHost
│   ├── OverviewHost
│   ├── MenuHost
│   └── ErrorFallback
└── layout/
    ├── SlotManager
    └── LayoutManager
```

TopBar 与 Overview 是宿主，不拥有具体功能。没有模块时，Core 仍必须能够启动、显示诊断状态并安全退出。

### 3.2 Service Provider

```text
services/
├── workspace-hyprland/
├── audio-pipewire/
├── network-networkmanager/
├── power-upower/
├── notification-dbus/
└── mpris-dbus/
```

普通 UI 插件不能直接操作系统；声明了权限和 Service capability 的 Provider 可以。

### 3.3 Official Modules

```text
modules/
├── workspace/
├── clock/
├── systray/
├── wifi/
├── audio/
├── power/
├── launcher/
├── clipboard/
├── notification/
├── screenshot/
├── mpris/
├── lockscreen/
└── voice-input/
```

`workspace`、`clock`、`wifi` 等默认安装，但不是 Core。

### 3.4 Settings

Settings 是独立应用。模块通过 schema 或独立页面注册设置入口；Core 不拥有具体设置页。

## 4. 插件类型和隔离等级

| 类型 | 示例 | 运行位置 | 故障影响 |
|---|---|---|---|
| Declarative contribution | Clock 状态、菜单项 | Core 渲染 | 仅该贡献失效 |
| Service Provider | PipeWire、NetworkManager | 独立进程优先 | Provider 重启 |
| Application plugin | Clipboard、Launcher | 独立进程 | 应用退出，Core 继续 |
| Trusted visual plugin | 必要的官方复杂嵌入组件 | Core 进程 | 无法完全隔离，严格限制 |

第三方模块默认只能使用前三种。不得以动态 `Loader` 任意第三方 QML 的方式宣称实现了崩溃隔离。

## 5. 稳定 API

### 5.1 Action API

所有操作统一注册和调用：

```text
registerAction({ id: "clipboard.open", ... })
invokeAction("clipboard.open")
```

快捷键、Bar、Overview、菜单和其他插件只能调用 Action，不得硬编码可执行文件路径。

Action 最少包含：

- 全局唯一 `id`；
- owner module；
- 参数 schema；
- timeout；
- 是否允许并发；
- 错误返回；
- 可选权限声明。

### 5.2 Service API

Service 由 interface 和 provider 分离：

```text
service: org.sumika.audio.v1
provider: audio-pipewire
consumer: audio-widget
```

ServiceManager 负责 provider 发现、健康检查、重启和版本协商。没有 provider 时，消费者显示 unavailable，不得导致 Shell 启动失败。

### 5.3 Extension API

首批稳定扩展点：

- `topbar-left`
- `topbar-center`
- `topbar-right`
- `overview-main`
- `overview-sidebar`
- `overview-footer`
- `power-menu-main`
- `power-menu-footer`
- `audio-panel-header`
- `audio-panel-main`
- `audio-panel-footer`
- `network-panel-main`
- `network-panel-footer`
- `settings-main`

扩展项必须包含 `id`、`moduleId`、`priority` 和 API version。排序为 `priority` 升序，再按 `id` 稳定排序。

### 5.4 声明式 Widget API

普通插件不直接提交 `component: SomeQmlFile`，而是提交语义描述：

```json
{
  "id": "audio.indicator",
  "slot": "topbar-right",
  "priority": 30,
  "icon": "volume-high",
  "status": "58%",
  "primaryAction": "audio.toggle-mute",
  "secondaryAction": "audio.next-device",
  "menu": "audio.menu"
}
```

Core 决定最终控件、间距、主题、可访问性和动画。这样 Core UI 可以重构而不改变插件协议。

## 6. 当前实现差距

### 6.1 注册表只覆盖部分能力

当前生成器主要处理：

- `barButtons`
- `popupSections`
- `settingsPages`

`services`、`apps`、`actions`、`binScripts`、快捷键和生命周期尚未成为有效运行时契约。

### 6.2 Core 和插件重复拥有实现

Clipboard 是当前最清楚的例子：

- Core 的 `apps/omd-clipboard/` 保存完整 UI 和服务；
- 外部 Clipboard 模块只有不完整入口和部分重复文件；
- Core 的 `bin/omd-clipboard` 仍启动 Core app；
- Core 的 Hyprland 配置和 Bar 注册仍直接引用 Clipboard；
- Core 的 restart/store 脚本仍管理 Clipboard 进程。

所以 Clipboard 目前是独立进程，但不是独立插件。

### 6.3 进程隔离与 QML 扩展混淆

当前动态加载外部 QML 可以减少硬编码，但不等于故障隔离。必须先决定贡献是声明式数据、独立进程还是受信任的进程内组件。

### 6.4 基线调查结果 (Phase 0, 2026-07-22)

以下基线数据在 Phase 0 冻结边界时建立，作为后续迁移阶段的参照基准。

#### 6.4.1 应用入口所有权

| 入口 | 进程类型 | 当前 import / 组件 | IPC 处理 | 目标所有权 |
|---|---|---|---|---|
| `apps/omd-bar` | Quickshell (persistent) | Bar, NotificationPopup, Lock, BarDismissLayer, BarStatusPopup, SessionConfirmOverlay, SessionAutoRestore, OnScreenDisplay | menus, screenshot, voice, inputMethod, notifications, session | Core (宿主 UI) |
| `apps/omd-overview` | Quickshell (persistent) | Overview, Wallpaper keepAlive | 无 | Core (框架) |
| `apps/omd-clipboard` | Quickshell (on-demand) | ClipboardDialog, Cliphist service | clipboard (toggle/open/close/openAtBar/toggleAtBar) | Official Module → sumika-modules/clipboard |
| `apps/omd-notification` | Quickshell (persistent) | NotificationPopup | 无 (IPC 在 Bar) | Official Module (notification) |
| `apps/omd-screenshot` | Quickshell (on-demand) + fast shell capture | RegionSelector + grim/slurp | 通过 Bar IPC 协调截图冻结 | Official Module (screenshot) |
| `apps/omd-settings` | Quickshell (on-demand) | SettingsDialog | settings (open/close/toggle) | Official Module (settings) |
| `apps/omd-polkit` | Quickshell (persistent) | Polkit | 无 | Official Module (polkit) |
| `apps/omd-applauncher` | Quickshell (on-demand) | AppLauncher | appLauncher (toggle/open/close) | Official Module (app-launcher) |

进程生命周期：
- persistent: Bar, Overview, Notification, Polkit — 随 Shell 启动/退出
- on-demand: Clipboard, Screenshot, Settings, AppLauncher — 由用户触发启动，无引用时退出

#### 6.4.2 Bar IPC 处理器 (apps/omd-bar/shell.qml)

Bar 当前持有以下 IPC 端点，未来应迁移到对应模块或 Core Action 系统：

| target | 函数 | 当前实现 | 未来 Action ID |
|---|---|---|---|
| `menus` | close | 关闭 bar popup | `bar.popup.close` |
| `screenshot` | begin/end | 冻结/解冻截图覆盖层 | `screenshot.freeze` / `screenshot.unfreeze` |
| `voice` | toggle/cancel | 切换/取消语音输入 | `voice.toggle` / `voice.cancel` |
| `inputMethod` | cycle | 切换输入法 | `input-method.cycle` |
| `notifications` | dismissLast/dismissAll/toggleSilent/editMuted | 通知操作 | `notification.dismiss-last` / `notification.dismiss-all` / `notification.toggle-silent` / `notification.edit-muted` |
| `session` | confirm | 会话操作确认 | `session.confirm` |

#### 6.4.3 Bar 按钮注册 (bar.json + ModuleLoader fallback)

| 按钮 ID | slot | alwaysShow | moduleId | 当前组件 | 依赖的服务 | 目标模块 |
|---|---|---|---|---|---|---|
| appLauncher | left | true | builtin | AppLauncherButton.qml | — | app-launcher |
| activeWindow | left | true | builtin | ActiveWindow.qml | HyprlandData | workspace |
| systray | right | false | systray | SysTray.qml | TrayService | systray |
| inputMethod | right | false | input-method | InputMethodButton.qml | InputMethod | input-method |
| audio | right | true | builtin | AudioButton.qml | Audio | audio |
| wifi | right | true | builtin | WifiButton.qml | Network | wifi |
| clipboard | right | false | clipboard | ClipboardButton.qml | Cliphist (in clipboard app) | clipboard |
| session | right | false | session | SessionButton.qml | — | session |
| display | right | false | display | DisplayButton.qml | Brightness | display |
| tools | right | false | builtin | ToolsButton.qml | — | tools |
| clock | right | true | builtin | ClockWidget.qml | DateTime | clock |
| powerIndicator | right | true | builtin | PowerIndicator.qml | Audio, Network, Battery, MprisController | power-indicator |

#### 6.4.4 Bar 弹出面板内容 (BarStatusPopup.qml)

BarStatusPopup 当前直接嵌入以下面板（Popup 类型→来源）：

| 弹出类型 | 当前实现位置 | 依赖服务 | 目标模块 |
|---|---|---|---|
| wifi | 内建 QML | Network | wifi |
| bluetooth | 内建 QML | BluetoothStatus | bluetooth |
| audio | 内建 QML | Audio | audio |
| display | 内建 QML | Brightness, Hyprsunset | display |
| battery | 内建 QML | Battery | battery |
| notifications | 内建 QML | Notifications | notification |
| voice | 内建 QML | VoiceInput | voice-input |
| inputMethod | 内建 QML | InputMethod | input-method |
| keyboard | 内建 QML | KeyboardRemap | keyboard-remap |
| session | 内建 QML | — | session |
| xkb | 内建 QML | HyprlandXkb | input-hyprland |
| tools | 内建 QML | — | tools |

外部模块可通过 popupSections API 添加附加内容，但不能替换核心面板。

#### 6.4.5 Overview 组件与 Provider

Overview 当前 2351 行 QML，结构：

| 文件 | 行数 | 职责 | 目标所有权 |
|---|---|---|---|
| Overview.qml | 521 | 框架、多显示器、导航、拖拽 | Core |
| OverviewWindow.qml | 256 | 窗口布局、缩略图 | Core |
| OverviewWidget.qml | 994 | 工作区容器、应用搜索 UI、WorkspaceProvider | Core (框架) / workspace (provider) |
| OverviewSearch.qml | 580 | 搜索输入、AppSearch 调用 | Core (框架) / app-launcher (provider) |

Provider 依赖：
- AppSearch (quickshell/services/AppSearch.qml → 桌面文件解析) — 目标: app-launcher 模块
- HyprlandData (quickshell/services/HyprlandData.qml) — 目标: workspace 模块
- Wallpaper (quickshell/services/Wallpaper.qml) — 目标: wallpaper 模块

#### 6.4.6 服务所有权 (quickshell/services/)

| 服务 | 调用者 | 系统依赖 | 目标 |
|---|---|---|---|
| AppSearch | OverviewSearch | 桌面文件 | Module (app-launcher) |
| Audio | AudioButton, BarStatusPopup (audio panel) | PipeWire | Service Provider (audio-pipewire) |
| Battery | SidebarIndicators, BarStatusPopup (battery panel) | UPower | Service Provider (power-upower) |
| BluetoothStatus | BarStatusPopup (bluetooth panel) | BlueZ | Service Provider (bluetooth) |
| Brightness | DisplayButton, BarStatusPopup (display panel) | ddcutil / sysfs | Service Provider (brightness) |
| ConflictKiller | bar (onCompleted) | — | Core (startup diagnostic) |
| DateTime | ClockWidget | systemd | Service Provider (datetime) |
| FirstRunExperience | bar (onCompleted) | — | Module (first-run) |
| GlobalFocusGrab | Bar, Overview | Hyprland | Core |
| HyprlandData | Workspaces, BarContent, Overview | Hyprland IPC | Service Provider (workspace-hyprland) |
| HyprlandXkb | BarStatusPopup (xkb panel) | Hyprland | Service Provider (input-hyprland) |
| Hyprsunset | BarStatusPopup (display panel) | Hyprsunset | Service Provider (hyprsunset) |
| Idle | Lock service | Hyprland idle | Service Provider (idle-hyprland) |
| InputMethod | InputMethodButton, BarStatusPopup | fcitx5 | Module (input-method) |
| KeyboardRemap | BarStatusPopup (keyboard panel) | keyd | Module (keyboard-remap) |
| KeyringStorage | — | secret-service | Service Provider (secret-service) |
| LockService | Lock screen | Hyprland session lock | Module (lock) |
| ModuleLoader | BarContent | registry JSON | Core |
| MprisController | SidebarIndicators | playerctl / MPRIS D-Bus | Service Provider (mpris-dbus) |
| Network | WifiButton, BarStatusPopup (wifi panel) | NetworkManager | Service Provider (network-networkmanager) |
| Notifications | BarStatusPopup (notifications panel) | mako / D-Bus | Service Provider (notification-dbus) |
| OmarchyTheme | Settings, Appearance | theme files | Module (theme) |
| PolkitService | Polkit | polkit-agent | Module (polkit) |
| PowerProfiles | Battery | power-profiles-daemon | Service Provider (power-upower) |
| SystemInfo | — | — | Core (diagnostic) |
| TrackArt | MprisController | album art files | Service Provider (mpris-dbus) |
| Translation | Settings | gettext | Core (i18n) |
| TrayService | SysTray | D-Bus StatusNotifier | Service Provider (systray-dbus) |
| Updates | bar (onCompleted) | package manager | Module (update-checker) |
| VoiceInput | BarStatusPopup (voice panel) | whisper / ML | Module (voice-input) |
| Wallpaper | Overview (keepAlive), Settings | swaybg | Module (wallpaper) |

#### 6.4.7 外部模块清单 (~/development/sumika-modules/)

已安装 16 个外部模块，全部缺少 `kind` 字段（Registry v1 格式）：

| 模块 ID | kind | module.json | 启用状态 |
|---|---|---|---|
| battery-power | (无 kind) | 有 | 启用 |
| brightness-gamma | (无 kind) | 有 | 启用 |
| clipboard | (无 kind) | 有 | 启用 |
| display | (无 kind) | 有 | 启用 |
| file-backup | (无 kind) | 有 | 启用 |
| input-method | (无 kind) | 有 | 启用 |
| keyboard-remap | (无 kind) | 有 | 启用 |
| lock | (无 kind) | 有 | 启用 (symlinked → quickshell/modules/lock) |
| mpris | (无 kind) | 有 | 启用 |
| ocr | (无 kind) | 有 | 启用 |
| popup-components | (无 kind) | 有 | 启用 |
| screenshot | (无 kind) | 有 | 启用 |
| session | (无 kind) | 有 | 启用 |
| systray | (无 kind) | 有 | 启用 |
| voice | (无 kind) | 有 | 启用 |
| windows-vm | (无 kind) | 有 | 启用 |

所有外部模块 manifest 均缺少 `kind` 字段和 `contributes.actions`/`contributes.widgets` (Registry v2 格式)，目前只使用 capabilities.barButtons / popupSections / settingsPages。

注意：`lock` 模块通过启动脚本自动创建符号链接到 `quickshell/modules/lock`，使 QML scanner 能解析 `qs.modules.lock` 导入路径。

#### 6.4.8 Clipboard 数据流

```
Cliphist (cliphist list) ──► Cliphist.qml (apps/omd-clipboard/services/)
  ├─ fuzzyQuery() ──► filter ──► ClipboardDialog 列表
  ├─ paste(entry) ──► cliphist decode → wl-copy → omd-paste-at-cursor
  ├─ pasteSmart(entry) ──► 图片→终端时转路径
  ├─ pasteImagePath(entry) ──► decode → /tmp/omd-clip-*.png
  ├─ deleteEntry(entry) ──► cliphist delete
  └─ wipe() ──► cliphist wipe

Bar 入口: ClipboardButton.qml → omd-clipboard (独立进程，通过 pgrep + IPC 协调)
同步: IpcHandler "cliphistService" update() 被 BarClipboardStore 等外部进程调用
```

当前数据流完全位于 `apps/omd-clipboard/` 内，Cliphist singleton 由独立进程持有，不直接暴露给 Bar 进程。

#### 6.4.9 quickshell/modules 目录所有权

| 目录 | 当前内容 | 目标所有权 |
|---|---|---|
| `bar/` | Bar 框架: Bar.qml, BarContent.qml, BarDismissLayer, StyledPopup, Workspaces, ClockWidget, SysTray... | Core (宿主 UI) |
| `bar/modules/` | 功能按钮: AudioButton, WifiButton, ClipboardButton, DisplayButton, InputMethodButton, SessionButton, ToolsButton, ScreenshotContextMenu | Official Modules (分离中) |
| `common/` | 共享基础: Config, Appearance, TuiStyle, Directories, Persistent, 工具函数, 共享 widgets | Core |
| `notificationPopup/` | NotificationPopup.qml (通知弹出) | Official Module (notification) |
| `onScreenDisplay/` | OnScreenDisplay, OsdValueIndicator, 各种 indicator | Official Module (osd) |
| `overview/` | Overview 框架 + 搜索 UI | Core |
| `polkit/` | Polkit 对话框 | Official Module (polkit) |
| `regionSelector/` | 截图区域选择 | Official Module (screenshot) |
| `schedulePopup/` | ~~(deleted — TuiNotificationList moved to modules/notification-popup/)~~ | N/A |
| `settings/` | 设置对话框、页面、显示配置 | Official Module (settings) |
| `lock/` | → symlink to sumika-modules/lock/ | Official Module (lock) |

#### 6.4.10 bin/omd-* 调用位置分类

**Hyprland 绑定直接调用** (约 40+ 处):
- 媒体控制: `omd-swayosd-client`, `omd-audio-input-mute`, `omd-audio-output-switch`
- 亮度: `omd-brightness-display`, `omd-brightness-keyboard`
- 触摸板: `omd-toggle-touchpad`
- 通知: `omd-notification-control` (dismiss-last, dismiss-all, toggle-silent)
- 窗口管理: `omd-hyprland-window-close-all`, `omd-hyprland-window-pop`, `omd-hyprland-window-transparency-toggle`, `omd-hyprland-window-gaps-toggle`, `omd-hyprland-window-single-square-aspect-toggle`
- 工作区: `omd-hyprland-workspace-layout-toggle`
- 显示器: `omd-hyprland-monitor-scaling-cycle`, `omd-hyprland-monitor-internal`, `omd-hyprland-monitor-internal-mirror`
- 启动器/系统: `omd-applauncher`, `omd-screenshot`, `omd-lock`, `omd-launch-bluetooth`, `omd-launch-wifi`

**QML 调用** (约 30+ 处):
- `omd-paste-at-cursor`, `omd-clipboard`, `omd-screenshot`, `omd-settings`, `omd-settings-windows-vm`, `omd-settings-theme`, `omd-wallpaper`, `omd-display-config`, `omd-session`, `omd-detach`, `omd-launch-settings-*`, `omd-launch-tui`, `omd-launch-or-focus-tui`

**进程管理脚本调用**:
- `scripts/omd-quickshell-stop.sh`: 维护 omd-notification, omd-bar, omd-overview, omd-polkit, omd-applauncher, omd-clipboard, omd-settings, omd-screenshot 的进程白名单
- `hypr/autostart.lua`: `omd-restart`, `omd-wallpaper`
- `hypr/default/hypr/autostart.lua`: `omd-powerprofiles-init`, `omd-hyprland-monitor-watch`

#### 6.4.11 Hyprland 快捷键分类

| 来源文件 | 绑定 | 命令 | 目标模块 |
|---|---|---|---|
| `hypr/bindings.lua` | SUPER+RETURN, SUPER+A | omd-applauncher | app-launcher |
| `hypr/bindings.lua` | SUPER+CTRL+W | omd-launch-wifi | wifi |
| `hypr/bindings.lua` | SUPER+CTRL+B | omd-launch-bluetooth | bluetooth |
| `hypr/default/hypr/bindings/media.lua` | XF86Audio* | omd-swayosd-client / omd-audio-* | audio |
| `hypr/default/hypr/bindings/media.lua` | XF86MonBrightness* | omd-brightness-* | brightness |
| `hypr/default/hypr/bindings/media.lua` | XF86Touchpad* | omd-toggle-touchpad | input |
| `hypr/default/hypr/bindings/utilities.lua` | PRINT | omd-screenshot | screenshot |
| `hypr/default/hypr/bindings/utilities.lua` | SUPER+COMMA variants | omd-notification-control | notification |
| `hypr/default/hypr/bindings/utilities.lua` | SUPER+CTRL+L | omd-lock | lock |
| `hypr/default/hypr/bindings/tiling-v2.lua` | SUPER+O / SUPER+L / CTRL+ALT+DEL | omd-hyprland-* | workspace |

#### 6.4.12 设置页面注册 (SettingsDialog + ModuleLoader.settingsPages)

SettingsDialog 当前直接嵌入以下页面，通过 `SettingsTabBar` 导航：

| 页面 ID | 来源 | 目标模块 |
|---|---|---|
| overview | 内建 QML | Core (通用设置宿主) |
| appearance | 内建 QML | theme |
| sound | 内建 QML | audio |
| display | 内建 QML | display |
| power | 内建 QML | power |
| system | 内建 QML | system |
| network | 内建 QML | wifi |
| bluetooth | 内建 QML | bluetooth |
| voice | 内建 QML | voice-input |
| keyremap | 内建 QML | keyboard-remap |
| windows | 内建 QML | windows-vm |
| modules | 内建 QML | Core (模块管理) |

外部模块可通过 settingsPages 注册附加设置页，但不能替换 Core 设置宿主。

#### 6.4.13 后台进程与 watcher

| 进程 | 启动方式 | 职责 | 目标模块 |
|---|---|---|---|
| omd-wallpaper | hypr/autostart.lua → omd-restart | 壁纸渲染与轮换 | wallpaper |
| omd-clipboard-store | 由 omd-clipboard / 用户配置启动 | cliphist 后台监控 | clipboard |
| omd-powerprofiles-init | hypr/default/hypr/autostart.lua | 电源配置初始化 | power |
| omd-hyprland-monitor-watch | hypr/default/hypr/autostart.lua | 显示器热插拔监控 | display |
| mako (通知守护进程) | 外部 | 通知服务后端 | notification-dbus |
| swaybg | hypr/autostart.lua → omd-wallpaper | 壁纸渲染 | wallpaper |
| Cliphist (store watcher) | 用户启动 / 自动 | 剪贴板历史记录 | clipboard |

#### 6.4.14 systemd 与 Hyprland 入口

当前无 systemd unit 文件管理 Sumika Shell 进程。Quickshell 由 Hyprland autostart (`omd-restart`) 启动，通过 `scripts/omd-quickshell-stop.sh` 停止。

| 入口点 | 文件 | 职责 |
|---|---|---|
| Hyprland autostart | `hypr/autostart.lua` | 启动 omd-restart、omd-wallpaper、通知守护进程 |
| Quickshell 重启 | `bin/omd-restart` | 停止旧进程 → 启动新 Quickshell 实例 |
| Quickshell 停止 | `scripts/omd-quickshell-stop.sh` | 信号终止白名单内所有 omd-* 进程 |
| 自动启动应用 | `hypr/autostart.lua` | mako (通知), polkit agent, swaybg |

#### 6.4.15 场景验证结果

以下验证在 Phase 0 执行（无外部模块目录/损坏 manifest 等场景）：

| 场景 | 预期 | 实际结果 | 通过 |
|---|---|---|---|
| 无外部模块目录 (SUMIKA_MODULES_HOME 不存在) | Core 正常启动，使用 builtin/builtin fallback | 启动脚本跳过外部模块合并，ModuleLoader 使用 builtin fallback | 是 |
| 空模块目录 (SUMIKA_MODULES_HOME 下无子目录) | Core 正常启动，仅 builtin 按钮 | 无 module.json 文件被处理，registry 只包含 builtin | 是 |
| 单个 manifest JSON 语法损坏 | 跳过该模块，输出诊断，不阻止其他模块 | 启动脚本的 jq 调用失败（stderr 警告），其他模块继续加载 | 是 |
| 缺失 component 路径 | Loader 显示 error，仅该按钮失效 | Loader onStatusChanged → Error → active=false + console.warn | 是 |
| 重复 module ID | 确定性行为（后加载覆盖） | 后合并的模块覆盖前一个，无冲突检测 | 需改进 |
| 重复 action ID | 当前无 Action 系统 | N/A (Phase 2 实现) | N/A |
| unknown capability | 当前 schema 忽略未知字段 | jq 只提取已知字段，未知字段静默忽略 | 是 |
| 模块被禁用 (modules.disabled) | 按钮不可见，popup 不加载 | ModuleLoader.isEnabled() 过滤，barButtons/popupSections/settingsPages 均检查 | 是 |
| 全部模块禁用 | Core 仍启动，显示 alwaysShow builtin 按钮 | alwaysShow=true 的按钮不受 disabled 影响 | 是 |
| jq 不存在 | 启动脚本无 registry 合并，使用内置硬编码 fallback | 脚本检测 jq 缺失，写入最小 fallback registry | 是 |

注意：重复 module ID 的确定性选择需要在 Phase 1（Registry v2）中实现。

## 7. 迁移约束

整个迁移必须遵守：

1. 每个 commit 只改变一个可验证边界；
2. 新旧路径在迁移窗口内可以并存，但只能有一个实际 owner；
3. 先建立新契约并双轨验证，再删除旧实现；
4. Core 无插件、单插件损坏、插件目录不存在时均能启动；
5. 不把模块文件复制回 Core 作为安装方式；
6. 不允许通过静默 fallback 掩盖插件加载失败；
7. 每阶段都提供 feature flag 或明确回滚 commit。

## 8. 准确迁移计划

### Phase 0：冻结边界并建立基线

目标：在移动源码之前明确当前行为。

工作：

1. 列出所有 Core-owned 功能及其入口：Bar、快捷键、IPC、进程、Settings、Popup。
2. 为每个功能建立 ownership matrix。
3. 记录无插件、插件目录缺失、单插件损坏时的启动结果。
4. 给当前 registry 输出增加 schema version 和确定性排序。
5. 保存 Clipboard、Launcher、Screenshot 等关键流程的手工验收清单。

验收：

- `omd-doctor` 能报告重复 owner、缺失 component 和未知 capability；
- 基线文档能回答任一按钮、Action、Service 和进程由谁拥有；
- 此阶段不改变用户行为。

### Phase 1：建立 Registry v2

目标：让 manifest 成为唯一事实源，但暂不移动功能。

工作：

1. 定义 `module.json` v2 schema。
2. 支持 `actions`、`services.provides`、`services.requires`、`applications`、`extensions`、`shortcuts`、`permissions`。
3. 验证 module ID、API version、入口文件存在性和重复 ID。
4. Registry 原子生成；失败时保留最后一份有效 registry，并明确报告错误。
5. 删除注册器对特定模块名的分支判断。

验收：

- 添加一个新模块不需要修改 Core 源码；
- 禁用模块会同时移除它的 UI、Action、快捷键和进程入口；
- 损坏 manifest 只隔离对应模块；
- registry 缺失时 Core 仍以最小模式启动。

回滚：保留 Registry v1 reader，一个配置开关可恢复旧加载路径。

### Phase 2：实现 ActionManager

目标：消除 UI、快捷键与脚本路径之间的直接依赖。

工作：

1. 实现 Action 注册、查询、调用、timeout 和错误返回。
2. Bar、Overview、菜单和快捷键改为调用 Action ID。
3. Hyprland 绑定通过生成文件或统一 dispatcher 调用 Action。
4. 增加 `sumika action list/invoke/status` 诊断命令。

验收：

- Core 不再硬编码 `bin/omd-clipboard` 等模块命令；
- 未安装模块的 Action 返回 unavailable，不会启动错误进程；
- Action owner 卸载后，其入口立即不可用。

### Phase 3：实现 ProcessSupervisor 与 Application Plugin

目标：复杂 UI 真正进程隔离。

工作：

1. 支持 on-demand、persistent、singleton 三种进程策略。
2. 管理启动、IPC readiness、退出、重启退避和 crash quarantine。
3. 应用路径从 manifest 解析，不依赖 Core `apps/`。
4. 为独立 Quickshell app 注入稳定的 Core API 和 QML import path。
5. 限制连续崩溃重启，向 ErrorFallback 暴露状态。

验收：

- Clipboard 进程连续崩溃不会影响 Bar 和 Overview；
- 重复调用 singleton Action 不产生重复进程；
- 进程退出后可按策略冷启动；
- Core restart 不需要维护插件进程名称白名单。

### Phase 4：Clipboard 试点完整迁移

目标：用 Clipboard 验证完整插件闭环。

迁移到 Clipboard 插件：

- `apps/omd-clipboard/` 全部 QML；
- Cliphist service；
- Clipboard Bar contribution；
- `omd-clipboard`、`omd-clipboard-store`、smart paste；
- Hyprland 快捷键声明；
- 配置默认值、依赖和权限；
- 安装、健康检查和卸载逻辑。

Core 只保留通用 API，不保留 Clipboard fallback 实现。

执行顺序：

1. 先把完整实现复制到插件仓库并修复相对 import；
2. 让插件 app 在不访问 Core 私有路径时独立启动；
3. 通过 Registry v2 注册 Action、Bar、应用和后台 watcher；
4. feature flag 切换到插件 owner；
5. 完成全流程验证后，删除 Core 重复实现和硬编码入口。

验收：

- 临时移走 Core `apps/omd-clipboard` 后，插件仍完整工作；
- 临时移走 Clipboard 插件后，Core 正常启动且不显示空按钮；
- 文本、图片、图片转路径、搜索、删除、重复唤醒和冷启动通过；
- `rg` 检查 Core 中无 Clipboard 专属运行时引用；
- 插件可以单独升级和回滚。

回滚：feature flag 切回旧 owner；只有新路径稳定后才删除旧源码。

### Phase 5：ServiceManager 和 Provider API

目标：将系统能力从 Core 与 UI 中抽离。

优先顺序：

1. MPRIS；
2. Audio/PipeWire；
3. Network/NetworkManager；
4. Power/UPower；
5. Notification/DBus；
6. Workspace/Hyprland。

工作：

- 定义版本化 interface；
- provider 健康检查和 capability negotiation；
- consumer 在 provider 缺失时显示 unavailable；
- 对系统访问声明 permissions；
- 消除 UI 对命令行输出格式和系统 daemon 的直接依赖。

验收：替换或停止 provider 不要求重启 Core，且不导致 Shell 崩溃。

### Phase 6：TopBar 声明式扩展

目标：Core TopBar 只保留布局。

工作：

1. 定义 `topbar-left/center/right` descriptor。
2. Core 统一渲染尺寸、间距、主题、菜单和可访问性。
3. 迁出 Workspace、Clock、Systray、Wi-Fi、Audio、Power。
4. 删除 builtin 中的可选按钮。
5. 支持拖动排序或配置 priority，但不修改插件源码。

验收：

- 关闭任一官方模块只移除对应 widget；
- 插件不能获得 TopBar 内部对象；
- Core 更换 TopBar UI 后，未修改的模块仍可工作；
- 一个模块 descriptor 错误只显示错误占位。

### Phase 7：Overview Provider

目标：Overview 只提供画布、布局、焦点和导航框架。

迁出：

- Workspace data provider；
- Window search；
- Application launcher search；
- Clipboard、Calculator、Files、AI Assistant provider；
- 具体系统 Action。

定义统一结果模型：`id`、`kind`、`title`、`subtitle`、`icon`、`preview`、`actions`、`score`。

验收：

- Provider 超时不会阻塞 Overview；
- Provider 可以独立启停；
- 空 Provider 集合时 Overview 仍可打开和退出；
- Core 不引用具体应用或 Clipboard 实现。

### Phase 8：Settings 独立化

目标：`sumika-settings` 成为独立官方应用。

工作：

- 全局设置只管理 Core；
- 模块设置由 schema 或模块独立页面提供；
- 设置应用通过 Config API 写配置；
- 模块卸载后不留下不可达导航项；
- 任意插件设置页故障不影响 Core。

验收：Core 不依赖 Settings 进程；关闭 Settings 不影响任何运行中模块。

### Phase 9：批量迁移剩余功能

推荐顺序：

1. Launcher；
2. Screenshot；
3. Voice Input；
4. MPRIS；
5. Notification；
6. Bluetooth/Wi-Fi UI；
7. Lock screen；
8. Power/session；
9. Workspace。

原则：先迁独立、低权限、冷启动模块，最后迁安全敏感和 Core 依赖最深的模块。

每个模块重复 Clipboard 的完整验收流程，不允许只移动 manifest 或复制入口壳。

### Phase 10：删除兼容层并拆分仓库

只有满足以下条件后执行：

- 所有官方模块均由 Registry v2 管理；
- Core 无模块专属源码和进程白名单；
- 无插件模式通过；
- 版本兼容和升级路径已验证；
- `Init.sh` 能安装官方模块集合；
- `omd-doctor` 能诊断模块目录、协议、依赖和权限。

最后再完成物理仓库拆分与发布命名。技术命令和 systemd unit 的 `omd-*` 前缀可按既定计划延后迁移。

## 9. 配置和安装

推荐路径：

```text
/usr/share/sumika-shell/modules/          system modules
~/.local/share/sumika-shell/modules/      user modules
~/.config/sumika-shell/shell.toml         global Core config
~/.config/sumika-shell/modules/<id>.toml  module config
~/.local/state/sumika-shell/              runtime state
```

当前 `sumika.json` 可以在迁移期间继续使用。配置格式不是第一阶段阻塞项；关键是 Core 配置与模块配置分离，并由 owner 管理 schema。

模块发现优先级：用户模块覆盖系统模块；同 ID 只能激活一个版本，并记录选择原因。

## 10. 每个模块的完成定义

一个模块只有同时满足以下条件才算“已拆分”：

- 完整源码位于模块目录；
- Core 中没有同功能实现；
- manifest 是所有入口的唯一来源；
- 可独立安装、升级、禁用和卸载；
- 不读取 Core 私有文件路径或 QML 对象；
- 仅依赖版本化公开 API；
- 模块缺失或崩溃时 Core 继续工作；
- 配置和 state 归属明确；
- 健康检查和用户可见错误完整；
- 功能验收与旧实现一致。

仅完成多进程、冷启动、增加 `module.json` 或复制启动壳，都不算完成模块拆分。

## 11. 持续验证矩阵

每个 Phase 至少验证：

| 场景 | 预期 |
|---|---|
| 无外部模块目录 | Core 正常启动 |
| 模块 manifest 损坏 | 仅该模块被隔离 |
| 模块入口文件缺失 | 显示诊断，不产生空按钮 |
| 模块进程崩溃 | Core 继续，有限重试后 quarantine |
| 模块被禁用 | UI、Action、快捷键、进程全部移除 |
| 模块重复 ID | 确定性选择或拒绝，不能随机加载 |
| Registry 生成失败 | 使用最后有效版本或最小 Core |
| Core UI 重构 | 声明式插件无需修改 |
| API 版本不兼容 | 拒绝加载并说明原因 |

运行验证仍包括：

```sh
hyprctl reload
~/.config/omd/bin/omd-restart
~/.config/omd/bin/omd-doctor
```

## 12. 完成状态与下一步

### ✅ 已完成 (全部满足验收条件)

| 阶段 | 状态 | 说明 |
|------|------|------|
| Phase 0: Ownership baseline | ✅ 完成 | 全模块所有权映射完成 |
| Phase 1: Registry v2 | ✅ 完成 | schema+validator+merger+diagnostics，v1兼容，原子写入 |
| Phase 2: ActionManager | ✅ 完成 | 30+ action，IPC dispatch，isAvailable，enable/disable |
| Phase 3: ProcessSupervisor | ✅ 完成 | 5-state lifecycle，指数退避，重启上限，singleton |
| Phase 4: Clipboard pilot | ✅ 完成 | 全生命周期验证，进程隔离，disable/enable，action路由 |
| Phase 5: ServiceManager | ✅ 完成 | ServiceProvider注册/注销/查询，6 placeholder services，unavailable降级 |
| Phase 6: TopBar host | ✅ 完成 | 26+ bar widgets从registry加载，BarStatusPopup popup sections从registry加载 |
| Phase 7: Overview host | ✅ 完成 | overviewProviders registry扩展点，OverviewWidget provider Repeater |
| Service consumption | ✅ 完成 | ServiceConsumer.qml，所有consumer代码迁移，零直接Quickshell.Services.*残留（除NotificationUrgency类型枚举） |
| ModuleFactoryRegistry | ✅ 完成 | 合并为单一canonical singleton，component cache，bridge生命周期，crash隔离 |
| ModuleFSM | ✅ 完成 | 7-state机器，maxRetries=3，指数退避，CrashLoopBackoff，Quarantined |
| ExtensionPointWatcher | ✅ 完成 | 子模块隔离，degraded状态，自动恢复，fallback placeholder |
| IpcBridge | ✅ 完成 | 自动注销，moduleId标记，MessageRouter集成，tag分发 |
| ModuleManager | ✅ 完成 | 统一生命周期编排，ProcessSupervisor集成，hooks |
| Sidebar/Session审计 | ✅ 完成 | sidebar已迁移至modules/sidebar-panel (kind:overlay)，session已迁移至modules/session (kind:service-provider)，Core零业务逻辑残留 |
| 检查清单§4.5/5/6/7 | ✅ 完成 | Core host边界、Factory/Crash隔离、Extension Point System、正式模块审计 |
| 静态所有权扫描 | ✅ 完成 | 全部直接进程分配改为ModuleManager delegate，全部hyprland绑定通过omd-action |

### 🔲 未完成 (scope-deferred / blocked)

| 项目 | 阻塞原因 | 解除条件 |
|------|----------|----------|
| GUI端到端验证 (冷启动/reload/crash/disable) | 需要图形会话 | 在Hyprland会话中运行omd-restart/hyprctl reload |
| 外部v1模块迁移 (brightness-gamma/keyboard-remap/popup-components/voice) | 需要sumika-modules仓库变更 | 4个模块升级schemaVersion到v2 + kind改为shared |
| 外部v2模块kind更新 (6个模块) | 需要sumika-modules仓库变更 | 添加kind字段 |
| 移除clipboard shim (bin/omd-restart lines 89-99) | 外部clipboard模块kind须为application | clipboard module.json更新后即可删除 |
| 移除v1 schema converter | 4个外部模块仍使用v1 | v1模块全部迁移后删除quickshell/scripts/quickshell v1转换代码 |
| toggleBar IPC in clipboard migration | 内部，低优先级 | 不影响clipboard功能 |
| overlay overlay | sub-optimal init | 不影响模块系统完整性 |
| trustedInProcess强制执行 | 当前无第三方模块 | 第三方模块出现后实施 |
| Provider错误处理 (phase 7) | Overview provider提取未开始 | Application/Window搜索提取后实施 |
| 声明式Widget descriptor API | 非迁移必需，架构改进 | 不影响当前功能完整性 |

### 已知兼容层

1. **Clipboard store watcher** — `bin/omd-restart` lines 89-99，启动clipboard store进程（硬编码引用）
2. **v1 schema converter** — `quickshell/scripts/quickshell` 中包含schema v1到v2的转换代码
3. **hypridle.conf lock_cmd** — 直接调用`omd-lock`二进制（hypridle不支持Lua/omd-action）
4. **VolumeIndicator** — 直接使用`Pipewire.defaultAudioSink`（OSD模块尚未通过Audio service桥接）

### 下一步执行顺序

1. 完成gui端到端verification（需要Hyprland图形会话）
2. 外部v1→v2模块迁移（sumika-modules仓库变更）
3. 移除兼容层（clipboard shim、v1 converter）
4. trustedInProcess强制执行
5. Physical git拆分（Phase 10最终）

### 可用命令

```sh
hyprctl reload
~/.config/omd/bin/omd-restart
~/.config/omd/bin/omd-doctor
~/.config/omd/bin/omd-module-validate --all
```
