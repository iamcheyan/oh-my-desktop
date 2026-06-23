# QuickShell 精简指南

> 目标：只保留你实际用到的核心功能，按模块逐步删除其余部分。  
> 相关文档：[startup-performance.md](./startup-performance.md)

---

## 使用方式

1. 从下表选一个模块，确认「你的状态」和「建议」
2. 按「删除步骤」操作
3. 重载 QuickShell：`pkill -x quickshell && quickshell -c ii -d`
4. 在本文档 **删除记录** 里打勾，继续下一个

**原则**：先删面板模块（`IllogicalImpulseFamily.qml` 里的 `PanelLoader`），再删对应 `services/`，最后清 `config.json`。

---

## 删除记录

| 日期 | 模块 | 状态 |
|------|------|------|
| 2026-06-20 | **AI 全套** | ✅ 已删除（见下文） |
| 2026-06-20 | **Waffle 全套** | ✅ 已删除（见下文） |
| 2026-06-20 | **SidebarLeft** | ✅ 已删除（见下文） |
| 2026-06-21 | **Overlay / Win+G** | ✅ 已删除（见下文） |
| 2026-06-21 | **Overview Search** | ✅ 已删除（见下文） |
| | | |

---

## ✅ 已删除：AI 全套（2026-06-20）

### 删除的文件

```
services/Ai.qml
services/LatexRenderer.qml          # 仅 AI 聊天 LaTeX 渲染用
services/ai/                        # 整个目录
modules/ii/sidebarLeft/AiChat.qml
modules/ii/sidebarLeft/aiChat/      # 整个目录
defaults/ai/                        # 整个目录
scripts/ai/                         # 整个目录
assets/icons/openai-symbolic.svg
```

### 修改的文件

| 文件 | 改动 |
|------|------|
| `modules/ii/sidebarLeft/SidebarLeftContent.qml` | 移除 AI 标签页 |
| `modules/ii/bar/LeftSidebarButton.qml` | 移除 AI 相关逻辑 |
| `modules/common/Config.qml` | 删除 `policies.ai`、`options.ai`、`sidebar.ai`、`aiStyling` |
| `modules/common/Directories.qml` | 删除 AI 路径与目录创建 |
| `modules/settings/GeneralConfig.qml` | 删除 AI 策略选项 |
| `modules/settings/ServicesConfig.qml` | 删除 system prompt 配置 |
| `modules/settings/BackgroundConfig.qml` | 删除 Gemini 时钟样式开关 |
| `modules/ii/background/widgets/clock/CookieClock.qml` | 删除壁纸分类自动样式 |
| `scripts/colors/switchwall.sh` | 删除 gemini 壁纸分类调用 |
| `welcome.qml` | 删除首次引导里的 AI 选项 |
| `~/.config/illogical-impulse/config.json` | 删除 `ai`、`policies.ai`、`sidebar.ai` |

### 你的配置影响

- 左侧边栏 AI 聊天：** gone **
- 状态栏左上角按钮：仅在开启翻译或 Anime 时显示（你当前两者都关，按钮应隐藏）
- 壁纸切换时不再调用 Gemini 分类

---

## 面板模块（`panelFamilies/IllogicalImpulseFamily.qml`）

Tier 说明见 [startup-performance.md](./startup-performance.md)。删除某模块 = 删掉对应 `PanelLoader { ... }` 行 + 删除 `modules/ii/<name>/` 目录。

| 模块 | 作用 | 你的状态 | 建议 | 删除步骤 |
|------|------|----------|------|----------|
| **Bar** | 顶栏：工作区、系统状态、托盘 | ✅ 使用中 | **保留** | — |
| **VerticalBar** | 竖向顶栏 | `bar.vertical: false` | 可删目录 | 删 `modules/ii/verticalBar/`；Bar 已覆盖 |
| **Background** | 壁纸背景层 | ✅ 使用中 | **保留** | — |
| **ScreenCorners** | 屏幕圆角装饰 | 默认开启 | 视审美 | 删 PanelLoader + `modules/ii/screenCorners/` |
| **OnScreenDisplay** | 音量/亮度 OSD 弹层 | ✅ 需要 | **保留** | — |
| **NotificationPopup** | 通知弹出气泡 | ✅ 需要 | **保留** | — |
| **Lock** | 锁屏界面 | 未开 `launchOnStartup` | **建议保留** | 锁屏仍可能需要 |
| **Overview** | Super 搜索 / 窗口概览 | `overview.enable: true` | **保留** | — |
| **AppLauncher** | 应用启动器面板 | 与 Overview 重叠 | 视习惯 | 删 PanelLoader + `modules/ii/appLauncher/` |
| **RegionSelector** | 截图/录屏/区域搜索 | 栏上有 snip/record | **保留** | — |
| **SessionScreen** | 电源菜单（注销/重启） | 常用 | **保留** | — |
| **Cheatsheet** | 快捷键 cheatsheet | 偶尔用 | 可选 | 删 PanelLoader + `modules/ii/cheatsheet/` |
| **OnScreenKeyboard** | 屏幕键盘 | 栏上键盘按钮关 | **可删** | 删 PanelLoader + `modules/ii/onScreenKeyboard/` |
| **Polkit** | 权限认证弹窗 | 系统需要 | **保留** | — |
| **SidebarLeft** | 左侧边栏 | — | ✅ 已删除 | 见下方「已删除」节 |
| **SidebarRight** | 右侧控制中心 | `cornerOpen.enable: true` | **保留** | — |
| **Dock** | 底部 Dock | `dock.enable: false` | **可删** | 删 PanelLoader + `modules/ii/dock/` |
| **MediaControls** | 浮动媒体控制 | 未明确使用 | 可选 | 删 PanelLoader + `modules/ii/mediaControls/` |
| **Overlay** | 笔记/准星/悬浮层 | — | ✅ 已删除 | 见下方「已删除」节 |
| **ScreenTranslator** | 屏幕 OCR 翻译 | 未明确使用 | **可删** | 删 PanelLoader + `modules/ii/screenTranslator/` |
| **WallpaperSelector** | 壁纸选择器 | 偶尔用 | 可选 | 删 PanelLoader + `modules/ii/wallpaperSelector/` + `services/Wallpapers.qml` |

## ✅ 已删除：SidebarLeft（2026-06-20）

左侧边栏（翻译 / Anime / 已删的 AI）在你配置下为空壳，但仍在 Tier 1 加载。

### 删除的文件/目录

```
modules/ii/sidebarLeft/           # 整个目录（12 文件）
modules/ii/bar/LeftSidebarButton.qml
```

### 修改的文件

| 文件 | 改动 |
|------|------|
| `panelFamilies/IllogicalImpulseFamily.qml` | 移除 `SidebarLeft` PanelLoader 与 import |
| `GlobalStates.qml` | 删除 `sidebarLeftOpen` 状态 |
| `modules/ii/verticalBar/VerticalBarContent.qml` | 移除左侧边栏按钮与点击切换 |
| `modules/ii/screenCorners/ScreenCorners.qml` | 左上/左下角改为空操作（保留亮度滚轮） |
| `modules/ii/background/Background.qml` | 视差仅响应右侧边栏 |

### 影响

- 左侧边栏及 `sidebarLeftToggle` 等 IPC 快捷键：**gone**
- 屏幕左上/左下角仍可滚轮调亮度，但不再打开侧边栏
- 竖栏顶部的左侧边栏按钮：**gone**
- Tier 1 少加载 1 个面板模块

---

## ✅ 已删除：Overlay / Win+G（2026-06-21）

Win+G 悬浮工具层包含准星、悬浮图片、FPS limiter、录屏控制、资源面板、便签和音量混合器镜像。它是独立面板模块，依赖右侧栏的 volume mixer，但右侧栏不反向依赖它。

### 删除的文件/目录

```
modules/ii/overlay/                         # 整个目录
modules/common/widgets/widgetCanvas/AbstractOverlayWidget.qml
assets/icons/crosshair-symbolic.svg
```

### 修改的文件

| 文件 | 改动 |
|------|------|
| `panelFamilies/IllogicalImpulseFamily.qml` | 移除 `Overlay` import 和 Tier 2 PanelLoader |
| `GlobalStates.qml` | 删除 `overlayOpen`、`crosshairOpen` |
| `modules/common/Config.qml` | 删除 `overlay`、`crosshair` 配置 |
| `modules/common/Persistent.qml` | 删除 overlay 持久化状态 |
| `modules/settings/InterfaceConfig.qml` | 删除 Overlay / Crosshair / Floating Image 设置 |

### 影响

- `quickshell:overlayToggle` / `overlay` IPC：**gone**
- Win+G 悬浮工具层：**gone**
- 右侧栏 volume mixer、RegionSelector 录屏/截图功能保留

---

## ✅ 已删除：Overview Search（2026-06-21）

Overview 现在只负责工作区/窗口管理。搜索、计算、运行命令、Emoji、Web 搜索和剪贴板搜索结果列表已经删除；剪贴板历史改由顶栏 `ClipboardDialog` 入口提供，Google Lens 保留在 RegionSelector 快捷键里。

### 删除的文件

```
modules/ii/overview/SearchWidget.qml
modules/ii/overview/SearchBar.qml
modules/ii/overview/SearchItem.qml
services/LauncherSearch.qml
services/Emojis.qml
modules/common/models/LauncherSearchResult.qml
```

### 修改的文件

| 文件 | 改动 |
|------|------|
| `modules/ii/overview/Overview.qml` | 移除搜索框、搜索状态、clipboard/emoji overview shortcuts |
| `modules/ii/bar/BarDialogOverlay.qml` | 新增 `barClipboardToggle` 全局快捷入口 |
| `modules/common/Config.qml` | `search` 只保留 `imageSearch` 配置 |
| `modules/settings/ServicesConfig.qml` | 删除 Search prefixes / web search 设置 |
| `~/.config/hypr/hyprland/keybinds.lua` | `Super+V` 改到 `barClipboardToggle`，移除 overview emoji/search 绑定 |

### 保留

- 顶栏剪贴板历史：`Cliphist` + `ClipboardDialog`
- Google Lens 区域搜索：`regionSearch`
- `AppSearch`：仍用于窗口、通知、音量混合器等图标推断

---

## ✅ 已删除：Waffle 全套（2026-06-20）

Windows 11 风格的备用面板家族，你一直在用 `ii`，Waffle 仅增加扫描/编译负担（约 144 个 QML 文件 + 936 KB Fluent 图标）。

### 删除的文件/目录

```
modules/waffle/                  # 整个目录（~712 KB，144 文件）
panelFamilies/WaffleFamily.qml
assets/icons/fluent/             # Waffle 专用 Fluent 图标（~936 KB，232 文件）
```

### 修改的文件

| 文件 | 改动 |
|------|------|
| `shell.qml` | 移除 Waffle 加载、面板切换快捷键与 IPC；仅保留 `IllogicalImpulseFamily` |
| `modules/common/Config.qml` | 删除 `panelFamily`、`options.waffles` |
| `modules/common/widgets/CalendarView.qml` | 动画改依赖 `Appearance`，不再 import `waffle.looks` |
| `~/.config/illogical-impulse/config.json` | 删除 `panelFamily`、`waffles` 段 |

### 影响

- 无法再切换到 Waffle 主题（`panelFamily cycle` 快捷键已移除）
- 启动时少扫描约 150 个 QML 文件
- ii 面板功能不受影响

---

## Singleton 服务（`services/`）

服务在首次被引用时加载。删掉面板后，对应服务可能变成死代码。

| 服务 | 作用 | 你的状态 | 建议 |
|------|------|----------|------|
| **HyprlandData** | hyprctl 窗口/工作区数据 | 核心依赖 | **保留** |
| **MaterialThemeLoader** | 主题色 | 核心 | **保留** |
| **Translation** | UI 翻译 | `language.ui: zh_CN` | 保留（体积不大） |
| **Config** | 配置读写 | 核心 | **保留** |
| **AppSearch** | 应用模糊搜索 | Overview 用 | **保留** |
| **LauncherSearch** | 启动器搜索 | — | ✅ 已删除 |
| **Cliphist** | 剪贴板历史 | 搜索 `;` 前缀 | 视习惯 |
| **Network** | WiFi/网络 | 右侧边栏 | **保留** |
| **BluetoothStatus** | 蓝牙 | 右侧边栏 toggle | **保留** |
| **Audio / Battery / Brightness** | 系统状态 | 顶栏 | **保留** |
| **ResourceUsage** | CPU/内存 | 顶栏资源显示 | **保留** |
| **Weather** | 天气 | `bar.weather.enable: true` | **保留**（不用可删） |
| **Notifications** | 通知管理 | 需要 | **保留** |
| **TrayService** | 系统托盘 | 顶栏托盘 | **保留** |
| **Updates** | pacman 更新检查 | `enableCheck: true` | 可关配置或删服务 |
| **Booru** | 动漫图搜索 | `weeb: 0` | **可删** |
| **SongRec** | 听歌识曲 | toggle 里有 | 不用可删 |
| **Todo** | 待办 | 右侧边栏 | 不用可删 |
| **TimerService** | 番茄钟 | 右侧边栏 | 不用可删 |
| **GoogleCloud** | 谷歌云翻译 API | 翻译关 | **可删** |
| **Wallpapers** | 壁纸浏览 | 壁纸选择器 | 不用选择器可删 |
| **EasyEffects** | 音效配置 | toggle 里有 | 不用可删 |
| **Emojis** | 表情搜索 | Overview `:` 前缀 | 不用可删 |
| **LatexRenderer** | — | 已随 AI 删除 | — |
| **Ai** | — | 已删除 | — |
| **FirstRunExperience** | 首次引导 | 一次性 | 保留无妨 |
| **ConflictKiller** | 冲突进程清理 | 安全相关 | 建议保留 |
| **Hyprsunset** | 夜间色温 | toggle 里有 | 视习惯 |
| **Idle** | 空闲检测 | 内部用 | 保留 |
| **PolkitService** | Polkit | 需要 | **保留** |
| **MprisController** | 媒体控制 | 媒体模块 | 删 MediaControls 后可审 |
| **KeyringStorage** | 密钥环 | 锁屏/GoogleCloud | GC 删后可简化 |
| **Privacy / SessionWarnings** | 隐私/会话警告 | 边缘功能 | 可选 |
| **Ydotool** | 模拟输入 | cliphist 粘贴 | Cliphist 删则一并审 |
| **GlobalFocusGrab** | 焦点抓取 | 多处依赖 | **保留** |
| **TaskbarApps** | 任务栏应用 | Dock 关 | 审 Dock 删除后处理 |
| **HyprlandConfig/Keybinds/Xkb** | Hyprland 集成 | cheatsheet 用 | 删 cheatsheet 后可审 |
| **HyprlandAntiFlashbangShader** | 防闪光 | toggle 用 | 视习惯 |
| **DateTime** | 时间 | 多处 | **保留** |
| **SystemInfo** | 系统信息 | 关于页/图标 | 保留 |

---

## 背景小部件（你当前全关）

`config.json` → `background.widgets.clock.enable: false`，`weather.enable: false`

可删除以减负：

```
modules/ii/background/widgets/clock/    # 整个目录
modules/ii/background/widgets/weather/
```

保留 `Background.qml` 本体（壁纸层仍需要）。

---

## 配置项速查（`~/.config/illogical-impulse/config.json`）

| 配置路径 | 关=省资源 | 你当前 |
|----------|-----------|--------|
| `dock.enable` | 删 Dock 模块 | `false` ✅ |
| `policies.weeb` | 删 Anime/Booru | `0` ✅ |
| `sidebar.translator.enable` | 删翻译页 | `false` ✅ |
| `bar.weather.enable` | 删 Weather 服务+栏组件 | `true` |
| `updates.enableCheck` | 推迟/关闭更新检查 | `true` |
| `overview.enable` | 删 Overview | `true` |
| `background.widgets.clock.enable` | 删时钟小部件 | `false` ✅ |
| `background.widgets.weather.enable` | 删天气小部件 | `false` ✅ |
| `startup.staggerPanelLoading` | 启动分档 | `true` ✅ |

---

## 推荐删除顺序（按你的配置）

按收益/风险排序，**一步一步来**：

1. ✅ **AI 全套** — 已完成
2. ✅ **Waffle 家族** — 已完成
3. ✅ **SidebarLeft 整块** — 已完成
4. **Dock** — 已 `enable: false`
5. **Booru 服务 + Anime 残留** — `weeb: 0` 时服务仍可能被引用
6. **OnScreenKeyboard** — 栏上按钮已关
7. **ScreenTranslator / MediaControls** — 按实际使用删
8. **背景 clock/weather 小部件代码** — 配置已关
9. **Cheatsheet / WallpaperSelector** — 低频功能
10. **翻译 JSON 其他语言** — 只留 `zh_CN.json` + `en_US.json`

---

## 验证清单

每次删除后：

```bash
timeout 8 quickshell -c ii -vv 2>&1 | grep -iE 'error|failed|Cannot find'
```

无报错后：

```bash
pkill -x quickshell; quickshell -c ii -d
```

手动测试：顶栏、Super 搜索、截图快捷键、右侧边栏、锁屏、通知。
