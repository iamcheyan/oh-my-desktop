# Sumika Shell 模块系统设计文档

> 状态：设计阶段（未实现）
> 日期：2026-07-20
> 目标：将可选功能拆分为独立模块，用户按需启用

---

## 1. 背景与动机

### 1.1 现状

当前 `~/development/OMD/quickshell/` 是一个 45K LOC 的单体 QML 代码库。所有功能（topbar、overview、输入法、语音、OCR、截图、虚拟机、备份、键盘映射）都编译进每个 Quickshell 进程。用户无法选择不加载某功能。

### 1.2 目标

- **可选功能模块化**：14 个可选功能拆为独立模块（显示器/输入法/语音/OCR/截图/虚拟机/备份/键盘映射/剪贴板/会话快照/媒体控制/系统托盘/电源电池/亮度夜间模式）
- **用户按需启用**：通过配置选择要加载的模块
- **独立仓库**：每个模块是独立 git 仓库，通过 submodule 引用
- **声明式注册**：模块自描述提供的能力（bar 按钮、设置页、服务、OSD、bin 脚本）
- **启动时扫描加载**：Quickshell 进程启动时扫描已启用模块

### 1.3 模块拆分原则

**最小核心**：只保留桌面运行必需的功能 —— 顶栏框架、工作区概览、主题系统、配置系统、基础窗口管理。其他一切可拆。

**拆分判据**：
1. 用户可能不需要这个功能（如：不用虚拟机、不用语音、不用 OCR）
2. 功能自成闭环（有自己的服务 + UI + bin 脚本）
3. 拆出后核心不受影响（核心不 import 模块的 QML）

### 1.4 完整模块清单（14 个可选模块）

#### 之前已确认的 8 个模块

| 模块 | 当前文件 |
------|----------|
| 显示器设置 | `settings/display/`, `bin/omd-display-config`, `bin/omd-hyprland-monitor-*` |
| 输入法 (fcitx) | `services/InputMethod.qml`, `bar/modules/InputMethodButton.qml`, OSD, `hypr/bindings` |
| 语音输入 | `services/VoiceInput.qml`, `settings/pages/VoicePage.qml`, `bin/omd-voice-*` |
| OCR | `bin/omd-ocr`, `bin/omd-settings-ocr*`, `share/bin/omarchy-capture-text-extraction` |
| 截图 | `modules/regionSelector/`, `bin/omd-screenshot`, `apps/omd-screenshot` |
| 虚拟机 | `settings/pages/WindowsVmPage.qml`, `bin/omd-settings-windows-vm`, `share/bin/omarchy-windows-vm` |
| 文件备份 | `file-share-backup/`, `bin/omd-settings-backup-tui`, `bin/omd-backup` |
| Keyboard Remap | `services/KeyboardRemap.qml`, `settings/pages/KeyboardRemapPage.qml`, `share/bin/omarchy-keyboard-*` |

#### 新增可拆模块（6 个）

| 模块 | 当前文件 | 理由 |
|------|----------|------|
| **剪贴板管理** | `apps/omd-clipboard/`（独立进程）, `bar/modules/ClipboardButton.qml`, `bin/omd-clipboard*`, `bin/omd-kitty-smart-paste` | 已是独立 Quickshell 进程，用户可能用 wl-clipboard 直接管理 |
| **会话快照** | `bar/SessionRestoreOverlay.qml`, `bar/SessionAutoRestore.qml`, `bar/SessionConfirmOverlay.qml`, `bar/BarStatusPopup.qml` 里的 session save/restore 逻辑, `bin/omd-session`, `common/functions/Session.qml` | 会话保存/恢复是高级功能，基础用户不需要 |
| **媒体控制 (MPRIS)** | `services/MprisController.qml`, `services/TrackArt.qml`, `BarStatusPopup.qml` 里的媒体控制区（1376-1712 行）, `bar/modules/` 媒体相关 | 用户可能不用媒体播放器，或用其他媒体控制工具 |
| **系统托盘** | `bar/SysTray.qml`, `bar/SysTrayItem.qml`, `bar/SysTrayMenu.qml`, `bar/SysTrayMenuEntry.qml`, `services/TrayService.qml` | 托盘是可选的，很多应用自带托盘图标 |
| **电源/电池** | `services/Battery.qml`, `services/PowerProfiles.qml`, `bar/BarBatteryIcon.qml`, `bar/PowerContextMenu.qml`, `settings/pages/PowerPage.qml` | 台式机没有电池；用户可能用其他电源管理 |
| **亮度/夜间模式** | `services/Brightness.qml`, `services/Hyprsunset.qml`, `onScreenDisplay/indicators/BrightnessIndicator.qml`, `onScreenDisplay/indicators/GammaIndicator.qml`, `bar/modules/DisplayButton.qml` 的亮度部分 | 外接显示器用户可能不用软件亮度控制 |

### 1.5 不拆分的核心（最小桌面必需）

| 核心模块 | 包含 | 理由 |
|----------|------|------|
| **Topbar 框架** | `bar/Bar.qml`, `bar/BarContent.qml`, `bar/Workspaces.qml`, `bar/ActiveWindow.qml`, `bar/ClockWidget.qml`, `bar/AppLauncherButton.qml` | Shell 骨架，所有模块的挂载点 |
| **Workspace Overview** | `overview/*` | 核心导航 |
| **Theme 系统** | `common/Appearance.qml`, `common/TuiStyle.qml`, `common/Config.qml`, `common/Directories.qml`, `common/Persistent.qml` | 所有 UI 的基础 |
| **锁屏** | `lock/*`, `services/LockService.qml` | 桌面安全必需 |
| **PolKit** | `polkit/*`, `services/PolkitService.qml` | 提权对话框必需 |
| **通知弹窗** | `notificationPopup/*`, `services/Notifications.qml` | 桌面通知是基础功能 |
| **通知历史中心** | `schedulePopup/*` | 通知查看是基础功能 |
| **OSD 框架** | `onScreenDisplay/OnScreenDisplay.qml`, `OsdValueIndicator.qml` | OSD 框架是核心，具体指示器（音量/亮度）由模块提供 |
| **设置框架** | `settings/SettingsDialog.qml`, `settings/widgets/*`, `settings/pages/AppearancePage.qml`, `settings/pages/OverviewPage.qml`, `settings/pages/SystemPage.qml` | 设置框架是核心；外观/概览/系统设置页是核心配置 |
| **核心服务** | `HyprlandData.qml`, `HyprlandXkb.qml`, `Audio.qml`, `Network.qml`, `BluetoothStatus.qml`, `Wallpaper.qml`, `DateTime.qml`, `SystemInfo.qml`, `GlobalFocusGrab.qml`, `Idle.qml`, `AppSearch.qml`, `Translation.qml`, `OmarchyTheme.qml`, `KeyringStorage.qml` | 桌面运行必需的服务 |
| **Audio 弹窗 + 音量 OSD** | `bar/modules/AudioButton.qml`, `BarStatusPopup.qml` 的 audioContent, `onScreenDisplay/indicators/VolumeIndicator.qml` | 音量控制是桌面基础功能（与"亮度"不同，几乎所有用户都需要） |
| **WiFi/蓝牙弹窗** | `bar/modules/WifiButton.qml`, `BarStatusPopup.qml` 的 wifi/bluetoothContent, `settings/pages/NetworkPage.qml`, `BluetoothPage.qml` | 网络连接是桌面基础功能 |

---

## 2. 架构设计

### 2.1 三层架构

```
┌─────────────────────────────────────────────────┐
│              用户配置 (~/.config/sumika-shell/)      │
│  config.json: modules.enabled = ["voice", "ocr", ...]  │
└──────────────────────┬──────────────────────────┘
                       │ 读取
┌──────────────────────▼──────────────────────────┐
│              模块加载层 (ModuleLoader)              │
│  启动时扫描 → 构建 import path → 注册能力            │
└──────────────────────┬──────────────────────────┘
                       │ 加载
┌──────────────────────▼──────────────────────────┐
│  Core (OMD repo)  │  Module: voice  │  Module: ocr  │ ...
│  topbar/overview  │  (submodule)    │  (submodule)  │
│  theme/config     │                 │               │
└─────────────────────────────────────────────────┘
```

### 2.2 仓库结构

```
~/development/OMD/                    # 核心仓库
├── quickshell/
│   ├── modules/                      # 核心 UI 模块（不可拆）
│   │   ├── bar/
│   │   ├── overview/
│   │   ├── common/                   # 核心 API + 共享 widgets
│   │   ├── lock/
│   │   ├── notificationPopup/
│   │   ├── onScreenDisplay/
│   │   ├── polkit/
│   │   ├── schedulePopup/
│   │   └── settings/                 # 设置框架（模块注册页面）
│   ├── services/                     # 核心服务（不可拆）
│   │   ├── Audio.qml
│   │   ├── HyprlandData.qml
│   │   ├── Network.qml
│   │   ├── Notifications.qml
│   │   ├── Wallpaper.qml
│   │   └── ...
│   ├── ModuleLoader.qml              # 模块加载器（新增）
│   ├── ModuleRegistry.qml            # 能力注册表（新增）
│   └── shell.qml                     # 各进程入口
├── modules/                          # submodule 目录（新增）
│   ├── voice/                        # git submodule → sumika-module-voice
│   ├── ocr/                          # git submodule → sumika-module-ocr
│   ├── screenshot/                   # git submodule → sumika-module-screenshot
│   ├── input-method/                 # git submodule → sumika-module-input-method
│   ├── display/                      # git submodule → sumika-module-display
│   ├── windows-vm/                   # git submodule → sumika-module-windows-vm
│   ├── file-backup/                  # git submodule → sumika-module-file-backup
│   ├── keyboard-remap/               # git submodule → sumika-module-keyboard-remap
│   ├── clipboard/                    # git submodule → sumika-module-clipboard
│   ├── session/                      # git submodule → sumika-module-session
│   ├── mpris/                        # git submodule → sumika-module-mpris
│   ├── systray/                      # git submodule → sumika-module-systray
│   ├── battery/                      # git submodule → sumika-module-battery
│   └── brightness-gamma/             # git submodule → sumika-module-brightness-gamma
├── bin/                              # 核心脚本
├── share/                            # 核心资源
└── Init.sh                           # 安装脚本（更新：初始化 submodule）

~/development/sumika-modules/         # 模块开发工作区（可选）
├── sumika-module-voice/              # 独立 git 仓库
├── sumika-module-ocr/
├── ...
└── README.md
```

### 2.3 模块仓库结构

每个模块是独立 git 仓库，标准结构：

```
sumika-module-voice/
├── module.json              # 模块清单（声明能力）
├── qmldir                   # QML 模块声明
├── services/
│   └── VoiceInput.qml       # 服务单例
├── bar/
│   └── VoiceButton.qml      # bar 按钮组件
├── settings/
│   └── VoicePage.qml        # 设置页
├── osd/
│   └── VoiceIndicator.qml   # OSD 指示器（可选）
├── bin/
│   ├── omd-voice-record
│   ├── omd-voice-transcribe
│   └── omd-voice-setup
├── scripts/
│   └── install.sh           # 模块依赖安装（pip 包等）
├── config.schema.json       # 该模块的配置 schema（合并到主 config.json）
├── README.md
└── LICENSE
```

---

## 3. module.json — 模块清单格式

每个模块根目录的 `module.json` 声明它提供的能力：

```json
{
  "id": "voice",
  "name": "语音输入",
  "version": "1.0.0",
  "description": "SenseVoice 语音转文字输入",
  "author": "Sumika Shell",
  "minCoreVersion": "1.0.0",

  "dependencies": {
    "modules": [],              // 依赖其他模块的 id
    "binaries": ["ffmpeg", "jq"],  // 依赖的外部命令
    "python": ["sherpa_onnx", "numpy"]  // 依赖的 Python 包
  },

  "capabilities": {
    "services": ["VoiceInput"],     // QML 服务单例名
    "barButtons": [{                // bar 按钮注册
      "component": "bar/VoiceButton.qml",
      "slot": "right",              // left | right | center
      "defaultOrder": 50,           // 默认排序权重
      "requiredConfig": "voice.enabled"  // 显示条件（可选）
    }],
    "settingsPages": [{             // 设置页注册
      "id": "voice",
      "title": "语音输入",
      "component": "settings/VoicePage.qml",
      "icon": "microphone",
      "order": 60
    }],
    "osdIndicators": [{             // OSD 指示器注册
      "component": "osd/VoiceIndicator.qml",
      "trigger": "voice.stateChanged"
    }],
    "ipcHandlers": [{               // IPC endpoint 注册
      "target": "voice",
      "actions": ["toggle", "cancel", "test"]
    }],
    "configSchema": "config.schema.json",  // 配置 schema
    "binScripts": "bin/"                   // bin 脚本目录
  },

  "configDefaults": {               // 合并到 config.json 的默认值
    "voice": {
      "enabled": true,
      "maxDuration": 90,
      "autoPaste": true
    }
  }
}
```

---

## 4. 加载机制

### 4.1 启动流程

```
用户运行 omd-bar
  │
  ▼
quickshell/scripts/quickshell（启动脚本）
  │
  ├─ 1. 扫描 OMD/modules/*/module.json
  │     获取物理存在的所有模块目录（即插即用，丢入目录即识别）
  │
  ├─ 2. 读取 ~/.config/sumika-shell/quickshell/config.json
  │     过滤掉用户显式在 "modules.disabled" 中声明禁用的模块，其余默认全部启用
  │
  ├─ 3. 构建 QML_IMPORT_PATH
  │     核心路径: OMD/quickshell/
  │     模块路径: OMD/modules/<id>/  （每个启用的模块）
  │     export QML_IMPORT_PATH=...
  │
  ├─ 4. 合并配置默认值
  │     核心默认 + 各模块 configDefaults → 用户 config 覆盖
  │
  ├─ 5. 自动编译/初始化校验（见第 14.4 节自构建机制）
  │     对首次丢入的模块，后台或同步执行 scripts/install.sh 进行就地编译/构建
  │
  ├─ 6. 生成模块注册表
  │     收集所有已启用模块的 module.json 的 capabilities
  │     写入 /tmp/sumika-module-registry.json
  │
  └─ 6. exec qs -p OMD/quickshell
        │
        ▼
     shell.qml 加载
       │
       ├─ import qs.core.*           # 核心
       ├─ import qs.ModuleLoader     # 模块加载器
       │
       └─ ModuleLoader 读取注册表
           ├─ 动态加载 bar 按钮
           ├─ 动态注册设置页
           ├─ 按需创建服务对象
           └─ 注册 IPC handler
```

### 4.2 ModuleLoader.qml — 核心加载器

```qml
// quickshell/ModuleLoader.qml
pragma Singleton
import QtQuick
import Quickshell.Io

Singleton {
    id: loader

    // 从环境变量读取注册表路径
    readonly property string registryPath: Quickshell.env("SUMIKA_MODULE_REGISTRY") ?? ""
    
    // 解析后的注册表
    readonly property var registry: {
        if (registryPath === "") return ({ services: [], barButtons: [], settingsPages: [] })
        const f = new QFile(registryPath)
        if (!f.open(QFile.ReadOnly)) return ({ services: [], barButtons: [], settingsPages: [] })
        return JSON.parse(f.readAll())
    }

    // 已加载的服务对象（按需创建）
    property var services: ({})

    // 获取服务（按需加载）
    function service(name) {
        if (services[name]) return services[name]
        const entry = registry.services.find(s => s.name === name)
        if (!entry) return null
        // 动态创建 Loader 加载服务 QML
        // ...
        return services[name]
    }

    // bar 按钮列表（按 order 排序）
    readonly property var barButtons: {
        return (registry.barButtons ?? [])
            .filter(b => b.slot === "right")
            .sort((a, b) => (a.defaultOrder ?? 100) - (b.defaultOrder ?? 100))
    }
}
```

### 4.3 Bar 按钮动态挂载

`BarContent.qml` 改为动态加载：

```qml
// BarContent.qml — 右侧按钮区
RowLayout {
    id: rightSectionRowLayout
    
    // 核心按钮（始终存在）
    SysTray { Layout.alignment: Qt.AlignVCenter }
    AudioButton { Layout.alignment: Qt.AlignVCenter }
    WifiButton { Layout.alignment: Qt.AlignVCenter }
    SessionButton { Layout.alignment: Qt.AlignVCenter }
    ClockWidget { Layout.alignment: Qt.AlignVCenter }
    
    // 模块按钮（动态加载）
    Repeater {
        model: ModuleLoader.barButtons
        delegate: Loader {
            required property var modelData
            source: modelData.component
            active: true
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
```

模块的 bar 按钮 QML 文件通过 import path 解析：

```qml
// OMD/modules/voice/bar/VoiceButton.qml
import qs.core
import qs.core.widgets

CircleUtilButton {
    // ...
}
```

### 4.4 设置页动态注册

`SettingsDialog.qml` 改为动态组装导航：

```qml
// SettingsDialog.qml
ColumnLayout {
    // 核心设置页（始终存在）
    SettingsNavItem { title: "外观"; page: appearancePage }
    SettingsNavItem { title: "网络"; page: networkPage }
    SettingsNavItem { title: "声音"; page: soundPage }
    
    // 模块设置页（动态加载）
    Repeater {
        model: ModuleLoader.settingsPages
        delegate: SettingsNavItem {
            required property var modelData
            title: modelData.title
            icon: modelData.icon
            page: Loader {
                source: modelData.component
                active: false  // 按需激活
            }
        }
    }
}
```

---

## 5. 核心 API 契约

模块只能依赖以下核心 API，不能依赖其他模块：

### 5.1 核心 QML 单例

| 单例 | 职责 | 稳定性 |
|------|------|--------|
| `Config` | 配置读写（`Config.options.voice.enabled`） | 🔒 稳定 |
| `Appearance` | Material You 主题色彩 | 🔒 稳定 |
| `TuiStyle` | TUI 风格调色板 | 🔒 稳定 |
| `Directories` | XDG 路径 | 🔒 稳定 |
| `GlobalStates` | 全局状态总线 | 🔒 稳定 |
| `HyprlandData` | 窗口/工作区数据 | 🔒 稳定 |
| `ModuleLoader` | 模块加载器 | 🔒 稳定 |
| `ModuleRegistry` | 能力注册表 | 🔒 稳定 |

### 5.2 核心共享组件

| 组件 | 路径 |
|------|------|
| `StyledText`, `StyledImage` | `core/widgets/` |
| `CircleUtilButton`, `RippleButton` | `core/widgets/` |
| `SettingsCard`, `SettingsRow`, `SettingsToggleRow` | `core/settings/widgets/` |
| `NerdIcon`, `MaterialSymbol` | `core/widgets/` |
| `StringUtils`, `FileUtils`, `ColorUtils` | `core/functions/` |

### 5.3 核心 bin 脚本

模块的 bin 脚本可以依赖：
- `lib/paths.sh` — 路径解析
- `share/bin/omarchy-*` — 底层工具

### 5.4 版本兼容

`module.json` 的 `minCoreVersion` 字段声明模块需要的最低核心版本。加载器检查版本兼容性，不兼容则跳过并警告。

---

## 6. 配置系统

### 6.1 用户配置

`~/.config/sumika-shell/quickshell/config.json` 新增 `modules` 段：

采用 **“黑名单制”** 管理，物理丢入 `modules/` 下的插件默认全部自动加载启用。用户仅需在 `disabled` 中声明想要停用的插件。

```json
{
  "modules": {
    "disabled": ["windows-vm", "file-backup"], // 仅在此声明禁用的模块，其余物理丢入的默认全部自动加载
    "barButtonOrder": {
      "voice": 45,
      "input-method": 50,
      "screenshot": 55,
      "display": 60
    }
  },
  "voice": { ... },           // 模块配置段
  "ocr": { ... },
  "inputMethod": { ... }
}
```

### 6.2 配置合并

启动时配置合并顺序：
1. 核心默认值（`defaults/config/quickshell/config.json`）
2. 各已启用模块的 `module.json` → `configDefaults`
3. 用户配置（`~/.config/sumika-shell/quickshell/config.json`）

后者覆盖前者。

### 6.3 Config.qml 适配

`Config.qml` 需要改为支持动态 schema（当前是硬编码 JsonObject）。方案：

**方案 A（推荐）**：保留硬编码核心配置，模块配置用动态 property
```qml
// Config.qml
property var moduleOptions: ({})  // 动态加载的模块配置

function moduleConfig(moduleId) {
    return moduleOptions[moduleId] ?? {}
}
```

模块通过 `Config.moduleConfig("voice").enabled` 读取自己的配置。

**方案 B**：全部动态化，Config.qml 从 schema JSON 生成。更灵活但重构工作量大。

---

## 7. 模块生命周期

### 7.1 服务按需加载

当前所有 `services/*.qml` 是 `pragma Singleton`，进程启动时全量创建。拆模块后：

- **核心服务**：保持 Singleton，启动时加载（Audio, HyprlandData, Notifications 等）
- **模块服务**：按需创建，通过 `ModuleLoader.service("VoiceInput")` 首次访问时加载

```qml
// 模块服务不再是 pragma Singleton
// 而是普通 QML 组件，由 ModuleLoader 管理
QtObject {
    id: voiceService
    // ... 服务逻辑
}
```

### 7.2 卸载

模块禁用时：
- 服务对象销毁（释放 Process、Timer 资源）
- bar 按钮移除
- 设置页移除
- IPC handler 注销

用户修改 `config.json` 的 `modules.enabled` 后需要 `omd-restart` 重启生效（热卸载 QML 组件风险较高）。

---

## 8. Init.sh 适配

### 8.1 Submodule 初始化

```bash
# Init.sh 新增
setup_modules() {
    info "Setting up modules..."
    
    # 初始化 submodule
    git submodule update --init --recursive
    
    # 读取用户配置的 enabled modules
    local config_file="${SUMIKA_SHELL_CONFIG_HOME:-...}/quickshell/config.json"
    local enabled
    enabled=$(jq -r '.modules.enabled[]?' "$config_file" 2>/dev/null)
    
    # 运行各模块的 install.sh（安装依赖）
    for module_id in $enabled; do
        local module_dir="$REPO/modules/$module_id"
        if [[ -x "$module_dir/scripts/install.sh" ]]; then
            info "Installing module: $module_id"
            "$module_dir/scripts/install.sh"
        fi
    done
    
    # 安装模块的 bin 脚本到 PATH
    for module_id in $enabled; do
        local module_bin="$REPO/modules/$module_id/bin"
        if [[ -d "$module_bin" ]]; then
            # symlink 到 ~/.local/bin 或加入 PATH
            for script in "$module_bin"/*; do
                ln -sf "$script" "$HOME/.local/bin/$(basename "$script")"
            done
        fi
    done
}
```

### 8.2 模块安装脚本

每个模块的 `scripts/install.sh` 负责安装自己的依赖：

```bash
#!/bin/bash
# sumika-module-voice/scripts/install.sh
set -eu

echo "Installing voice module dependencies..."

# Python 依赖
pip install --user sherpa_onnx numpy

# 系统依赖（通过包管理器）
if command -v pacman >/dev/null; then
    pacman -Q ffmpeg >/dev/null || sudo pacman -S --noconfirm ffmpeg
fi

echo "Voice module ready."
```

---

## 9. 模块拆分清单

### 9.1 优先级排序（按独立性从高到低）

| 优先级 | 模块 | 当前文件 | 独立性 | 依赖 |
|--------|------|----------|--------|------|
| P0 | OCR | `bin/omd-ocr`, `bin/omd-settings-ocr*` | 很高 | 仅 bin 脚本 + Python |
| P0 | 文件备份 | `file-share-backup/`, `bin/omd-settings-backup-tui` | 很高 | 自包含 |
| P1 | 虚拟机 | `settings/pages/WindowsVmPage.qml`, `bin/omd-settings-windows-vm`, `share/bin/omarchy-windows-vm` | 高 | Hyprland 窗口规则 |
| P1 | 语音输入 | `services/VoiceInput.qml`, `settings/pages/VoicePage.qml`, `bin/omd-voice-*` | 高 | Config, GlobalStates |
| P1 | 剪贴板管理 | `apps/omd-clipboard/`, `bar/modules/ClipboardButton.qml`, `bin/omd-clipboard*` | 高 | Config, GlobalStates |
| P1 | 电源/电池 | `services/Battery.qml`, `services/PowerProfiles.qml`, `settings/pages/PowerPage.qml` | 高 | Config, DBus, UPower |
| P1 | 系统托盘 | `bar/SysTray.qml`, `services/TrayService.qml` | 中高 | TrayService, Config |
| P2 | 显示器设置 | `settings/display/*`, `bin/omd-display-config`, `bin/omd-hyprland-monitor-*` | 中 | HyprlandData, Config |
| P2 | Keyboard Remap | `services/KeyboardRemap.qml`, `settings/pages/KeyboardRemapPage.qml`, `share/bin/omarchy-keyboard-*` | 中 | HyprlandData, bar 按钮, OSD |
| P2 | MPRIS 媒体控制 | `services/MprisController.qml`, `BarStatusPopup.qml` 媒体区 | 中 | Config, Mpris |
| P2 | 亮度/夜间模式 | `services/Brightness.qml`, `services/Hyprsunset.qml`, OSD 指示器 | 中 | Config, OSD |
| P3 | 截图 | `modules/regionSelector/*`, `bin/omd-screenshot` | 中 | GlobalStates, bar 按钮 |
| P3 | 输入法 | `services/InputMethod.qml`, `bar/modules/InputMethodButton.qml`, OSD | 中 | bar 按钮, OSD, Config |
| P3 | 会话快照 | `bar/SessionRestoreOverlay.qml`, `bin/omd-session`, `common/functions/Session.qml` | 中低 | Config, HyprlandData |

### 9.2 每个模块拆分的步骤模板

1. 创建独立 git 仓库 `sumika-module-<id>`
2. 复制相关文件到模块仓库
3. 编写 `module.json` 声明能力
4. 编写 `qmldir` 声明 QML 模块
5. 编写 `config.schema.json` 声明配置
6. 编写 `scripts/install.sh` 安装依赖
7. 改 import 路径：`import qs.services` → `import qs.core`
8. 在 OMD 仓库添加为 submodule：`git submodule add <url> modules/<id>`
9. 从 OMD 仓库删除原文件
10. 更新 `ModuleLoader` 识别新模块
11. 测试：`omd-restart` 后功能正常

---

## 10. 关键设计决策

### 10.1 为什么用 submodule 而不是 monorepo

- **独立版本化**：模块可以有自己的发版周期
- **可选安装**：用户可以只 clone 需要的模块
- **社区贡献**：第三方可以开发模块，不需要修改核心仓库
- **权限隔离**：模块维护者不需要核心仓库的写权限

### 10.2 为什么用启动时扫描而不是编译时链接

- Quickshell 是解释执行 QML，没有编译步骤
- 启动时扫描 `module.json` 成本极低（~10 个文件，<1ms）
- 用户修改 `config.json` 后只需 `omd-restart`，无需重新编译

### 10.3 为什么用声明式注册而不是固定插槽

- 模块数量不确定，固定插槽需要预留过多
- 声明式让模块自描述能力，核心不需要知道有哪些模块
- 用户可以通过 `barButtonOrder` 自定义顺序

### 10.4 为什么服务按需加载而不是全量 Singleton

- 当前 30+ 服务全量加载，启动时创建所有 Process/Timer 对象
- 模块化后可能有 40+ 服务，禁用的模块不应占内存
- 按需加载：首次 `ModuleLoader.service("VoiceInput")` 时创建

---

## 11. 风险与权衡

### 11.1 性能风险

| 风险 | 影响 | 缓解 |
|------|------|------|
| 启动时扫描模块 | +~5ms | 可接受（Quickshell 启动本身 ~500ms） |
| 动态 Loader 加载 bar 按钮 | 首次 +~10ms/按钮 | 用 `LazyLoader` 延迟加载 |
| 配置合并开销 | +~2ms | JSON 合并很快 |

### 11.2 兼容性风险

| 风险 | 缓解 |
|------|------|
| 核心 API 变动破坏模块 | 版本号 + minCoreVersion 检查 |
| 模块间隐式依赖 | module.json 的 dependencies 声明 + 加载器检查 |
| 配置 schema 冲突 | 每个模块的配置在独立 namespace 下（`voice.*`, `ocr.*`） |

### 11.3 开发体验

| 问题 | 解决 |
|------|------|
| 开发时需要频繁更新 submodule | 文档说明 `git submodule update --remote` |
| 调试时模块 QML 报错路径不直观 | ModuleLoader 记录加载日志 |
| 新模块开发者不知道怎么写 | 提供 `module-template/` 脚手架仓库 |

---

## 12. 实现路线图

### Phase 1：核心基础设施（1-2 天）
- [ ] 创建 `ModuleLoader.qml` + `ModuleRegistry.qml`
- [ ] 修改 `quickshell/scripts/quickshell` 启动脚本（扫描模块、构建 import path）
- [ ] 修改 `Config.qml` 支持动态模块配置
- [ ] 修改 `BarContent.qml` 支持动态 bar 按钮
- [ ] 修改 `SettingsDialog.qml` 支持动态设置页

### Phase 2：试点模块（2-3 天）
- [ ] 拆出 `sumika-module-ocr`（最独立，验证流程）
- [ ] 拆出 `sumika-module-file-backup`（第二独立）
- [ ] 验证：禁用模块后 bar/设置页正确消失，启用后恢复

### Phase 3：批量拆分（3-5 天）
- [ ] 拆出 `sumika-module-voice`
- [ ] 拆出 `sumika-module-windows-vm`
- [ ] 拆出 `sumika-module-display`
- [ ] 拆出 `sumika-module-keyboard-remap`
- [ ] 拆出 `sumika-module-screenshot`
- [ ] 拆出 `sumika-module-input-method`
- [ ] 拆出 `sumika-module-clipboard`
- [ ] 拆出 `sumika-module-session`
- [ ] 拆出 `sumika-module-mpris`
- [ ] 拆出 `sumika-module-systray`
- [ ] 拆出 `sumika-module-battery`
- [ ] 拆出 `sumika-module-brightness-gamma`

### Phase 4：文档与工具（1 天）
- [ ] 编写模块开发指南（`docs/module-development.md`）
- [ ] 创建 `sumika-module-template` 脚手架仓库
- [ ] 更新 `Init.sh` 支持 submodule 初始化
- [ ] 更新 `omd-doctor` 检查模块状态

---

## 13. open questions

1. **模块的 bin 脚本怎么暴露到 PATH？**
   - 方案 A：`Init.sh` 时 symlink 到 `~/.local/bin/`
   - 方案 B：`omd-path.sh` 动态添加模块 bin 到 PATH
   - 倾向 B（动态，不污染 ~/.local/bin）

2. **模块的翻译怎么合并？**
   - 当前翻译在 `quickshell/translations/`，模块自己的翻译放哪？
   - 方案：模块提供 `translations/<lang>.json`，启动时合并到翻译表

3. **模块可以覆盖核心行为吗？**
   - 当前设计是"添加"能力（新按钮、新页面、新服务）
   - 是否允许"覆盖"（如替换默认音频按钮）？
   - 倾向：不允许，保持核心稳定

4. **模块间通信？**
   - 模块 A 需要调用模块 B 的服务怎么办？
   - 方案：通过 `ModuleLoader.service("B")` 获取，或在 `module.json` 声明依赖
   - 倾向：声明依赖 + `ModuleLoader.service()` 查询

5. **Hyprland 配置怎么模块化？**
   - 模块可能需要注册 Hyprland 窗口规则/快捷键
   - 方案：模块提供 `hypr/overrides.lua`，用户配置加载

---

## 14. 异构语言插件设计规范（Go / Python / 编译语言支持）

为了支持 Python、Go、Rust、C++ 等多语言混合开发的插件，系统采用**“标准构建契约 + 运行时动态 PATH 注入”**的架构，避免写死路径或手动软链接。

### 14.1 目录结构与成果物规范

每个插件必须将可执行成果物（脚本或编译后的二进制）统一放置在 `bin/` 目录下：

```
sumika-module-<id>/
├── module.json
├── qmldir
├── bin/                       # 必须：所有的可执行产物存放于此
│   └── omd-<id>-helper        # Python 脚本、编译好的 Go/Rust 程序或 C++ 二进制
├── scripts/
│   └── install.sh             # 必须：负责该模块在当前平台的构建与依赖安装
```

### 14.2 生命周期构建契约（`install.sh`）

核心框架不负责插件的具体编译与依赖管理，而是在初始化（`Init.sh`）或插件启用时，委托插件自主执行 `scripts/install.sh`：

* **Python 插件**：在 `install.sh` 中配置插件专属的虚拟环境（venv），或者安装对应的 pip 包。
  ```bash
  # Python 编译/安装示例
  python3 -m venv venv
  ./venv/bin/pip install -r requirements.txt
  # 在 bin/ 下创建一个指向 venv 的包装加载脚本
  ```
* **Go / Rust / 编译语言插件**：在 `install.sh` 中调用本地编译器进行就地编译，将成果物输出至 `bin/` 目录。
  ```bash
  # Go 编译示例
  go build -o ../bin/omd-<id>-helper main.go
  ```
* **第三方成品（如 Quick Share）**：若无本地编译环境，`install.sh` 可负责拉取对应架构的 Prebuilt 二进制包，并解压至 `bin/` 下。

### 14.3 运行时动态 PATH 隔离注入

QML、Shell 或 TUI 在调用插件的后台服务时，一律**禁止使用相对路径或绝对路径硬编码**（例如不使用 `../../modules/ocr/bin/omd-ocr`），而是直接呼叫命令名称（如 `omd-ocr`）。

由 `bin/omd-run` 或环境装载器在启动时，动态收集所有 `enabled` 模块的 `bin/` 路径，并一次性注入到 `PATH` 环境变量中：

```bash
# quickshell/scripts/quickshell 或 omd-run 启动逻辑
# 动态计算并导出 PATH
for module_id in $(jq -r '.modules.enabled[]?' "$CONFIG_JSON"); do
    module_bin="$OMD_ROOT/modules/$module_id/bin"
    if [[ -d "$module_bin" ]]; then
        export PATH="$module_bin:$PATH"
    fi
done
```

#### 💡 设计优势：
1. **零路径硬编码**：核心 UI 和其他组件仅需调用 `omd-ocr` 等命令名，完全无需感知模块文件被部署在何处。
2. **多语言自由**：插件开发者可以使用最适合的语言（Go 高性能、Python 机器学习、Bash 快捷控制），只要能编译/生成可在 `bin/` 下执行的同名文件即可。
3. **按需环境隔离**：每个插件各自处理依赖，不污染全局系统路径或全局 Python 环境。

### 14.4 零操作自构建机制（即插即用 / 零安装）

为了实现“插件目录直接丢进去，Reload 时自动启用且自动跑起来”的极致体验，系统采用**“状态哨兵自构建”**方案：

1. **自动扫描发现**：环境加载器每次启动或 Reload 时，直接扫描 `OMD/modules/*/module.json`，存在即代表已安装，默认自动激活（除非在黑名单中）。
2. **哨兵校验 (.installed)**：
   * 启动脚本在扫描到插件后，检测其根目录下是否存在 `.installed` 哨兵标记文件（或检查 `bin/` 下对应二进制是否存在）。
   * 若**不存在**，代表该插件是首次被“丢入”系统或刚刚被拉取：
     1. 加载器自动在后台或加载准备阶段静默运行该插件的 `scripts/install.sh`。
     2. 自行编译 Go/Rust 程序或创建 Python venv 虚拟环境。
     3. 编译/安装成功后，系统自动写入 `.installed` 哨兵文件（记录编译时间及版本）。
   * 若**已存在**，则直接跳过构建步骤，进行毫秒级极速装载。

通过该机制，用户从外界拉取或拷贝一个 Go/Python 编写的外部插件（如 `sumika-module-windows-vm`）到 `modules/` 目录下后，**无需手动执行任何 build、make 或 pip 命令**，直接按下系统重新加载快捷键，插件就会在后台自动完成编译/配置，并瞬间在顶栏和设置中心亮起！

### 14.5 顶栏按钮挂载与快捷键触发通讯机制

插件与主程序（顶栏 Topbar 及窗口管理器 Hyprland）的通讯核心在于两点：**“动态 QML 锚点挂载”** 与 **“声明式快捷键映射”**。

#### 14.5.1 顶栏图标动态挂载（Topbar Slot Binding）

顶栏不预先为任何可选模块预留固定的插槽，而是通过 `module.json` 进行声明式注册：

```json
// sumika-module-voice/module.json 示例
"capabilities": {
  "barButtons": [{
    "component": "bar/VoiceButton.qml", // 按钮对应的组件相对路径
    "slot": "right",                     // 挂载位置：left | center | right
    "defaultOrder": 45                   // 默认排序权重
  }]
}
```

* **QML 侧加载**：
  主顶栏的右侧按钮区（`BarContent.qml`）使用 `Repeater` 读取加载器列表，将模块按钮包装为 `Loader` 载入：
  ```qml
  Repeater {
      model: ModuleLoader.barButtons.filter(btn => btn.slot === "right")
      delegate: Loader {
          source: "file://" + modelData.absoluteComponentPath
          Layout.alignment: Qt.AlignVCenter
      }
  }
  ```

#### 14.5.2 快捷键触发与通讯机制（Hotkey Binding）

按需启用的插件（例如截图、剪贴板、语音输入开关）通常需要绑定系统快捷键。为了保持底层解耦，系统提供两种快捷键通信链路：

1. **声明式快捷键绑定（由核心统一生成配置）**：
   模块在其 `module.json` 中声明自己期望绑定的系统快捷键与动作：
   ```json
   "bindings": [
     {
       "key": "Alt, A",
       "action": "omd-voice toggle"       // 触发时执行的 shell 脚本命令
     },
     {
       "key": "Super, V",
       "action": "qs -p omd-clipboard ipc call clipboard toggle" // 触发时发送给 QML 的 IPC 通信
     }
   ]
   ```
   * **运行原理**：每次系统重新加载（`omd-restart`）时，加载程序会扫描所有激活插件的 `bindings` 项，自动生成一份临时的 Hyprland 快捷键绑定配置文件（例如 `~/.local/state/sumika-shell/hypr/bindings_modules.conf`）。
   * **自动注入**：主 Hyprland 配置文件中动态 `source` 这个生成文件。当插件被移除或禁用时，对应的快捷键就会物理消失，**完全不污染主配置**。

2. **核心层安全垫片（Safety Fallback Shim）**：
   对一些固定的、极度常用的快捷键（如截图 `PrintScreen`），主程序仍然可以在 `hypr/bindings.conf` 中写死。但调用的指令是一个**核心安全外壳命令**（例如 `omd-screenshot`）。
   * 如果截图插件已启用，`PATH` 中会有该命令，正常执行；
   * 如果截图插件未装载，该命令执行时会检测到命令不存在，触发核心默认的轻量提示（“截图模块未安装”），保证系统绝对不崩溃、不闪退。

---

## 15. 进阶边界考虑与容错设计清单

在真实的桌面环境中，一个优秀的插件系统还需要解决**“异常隔离”**、**“本地化冲突”**和**“系统权限”**等隐性问题。以下是必不可少的工程设计清单：

### 15.1 异常隔离：单个插件崩溃，不黑屏 (Error Isolation)

* **问题**：如果用户丢入的第三方插件 QML 存在语法错误（如缺少花括号、找不到 import），它会不会导致整个顶栏（Topbar）报错中断加载，进而让用户面临“黑屏无顶栏”的灾难？
* **方案**：顶栏动态加载模块按钮的 `Loader` 必须包含错误兜底：
  ```qml
  Repeater {
      model: ModuleLoader.barButtons
      delegate: Loader {
          id: buttonLoader
          source: "file://" + modelData.absoluteComponentPath
          // 容错处理：加载失败时不引起上层崩溃
          onStatusChanged: {
              if (status === Loader.Error) {
                  console.warn(`[Module System] Failed to load module ${modelData.id}:`, errorString());
                  // 可以选择在这里装载一个默认的警告图标或直接隐藏
                  active = false; 
              }
          }
      }
  }
  ```

### 15.2 插件的国际化翻译合并 (i18n Merging)

* **问题**：如果插件自己包含英文和中文翻译，如何无缝融入核心系统的中英文切换？
* **方案**：
  * 插件必须在 `translations/` 下提供标准的语言包文件（例如 `zh.json`, `en.json`）。
  * 核心系统的加载器在生成注册表时，自动合并各激活模块的 JSON 翻译字典至 `/tmp/sumika-merged-translations.json`，供 `Translation.qml` 统一调配。

### 15.3 系统级特权与依赖检测 (System Sudo / Udev / Systemd)

* **问题**：部分插件不仅仅是 UI，它还涉及系统层面的改动（例如键盘映射需要开启并控制 `keyd.service`；网络或电源控制可能涉及特殊的 udev 规则）。这些在“丢入目录”后无法自动生效。
* **方案**：
  * **在 `install.sh` 中完成提权配置**：如果哨兵文件 `.installed` 缺失，执行自编译构建时，若涉及系统配置，可在控制台（TUI）或在 `install.sh` 中合理调用 `sudo` 进行环境配置。
  * **利用系统哨兵工具检查**：核心自带的检查程序 `bin/omd-doctor` 需增加模块化检测接口。当运行 `omd-doctor` 时，除了检查主系统健康度外，还要自动轮询 `modules/*/scripts/check-health.sh`（如果有的话），向用户输出明确的模块环境状态。

### 15.4 命名空间防冲突限制 (Namespace Collision)

* **问题**：如果两个不同的作者都开发了名为 `clipboard` 的插件并丢进目录，或者两个插件都注册了相同的 IPC 方法名，会发生覆盖冲突。
* **方案**：系统在加载器中强制做三项隔离约束：
  1. **目录即 ID**：插件在 `modules/` 下的目录名即为它的唯一 `id`。
  2. **配置隔离**：每个插件在配置中心仅拥有以 `id` 命名的独立命名空间子树（如 `Config.options.modules[id]`）。
  3. **IPC 方法前缀**：IPC 动作注册一律强制带上前缀 `org.omd.module.<id>.*`。