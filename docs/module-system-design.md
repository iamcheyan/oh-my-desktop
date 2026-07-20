# Sumika Shell 模块系统设计文档

> 状态：设计阶段（未实现）
> 日期：2026-07-20
> 目标：将可选功能拆分为独立模块，用户按需启用

---

## 1. 背景与动机

### 1.1 现状

当前 `~/development/OMD/quickshell/` 是一个 45K LOC 的单体 QML 代码库。所有功能（topbar、overview、输入法、语音、OCR、截图、虚拟机、备份、键盘映射）都编译进每个 Quickshell 进程。用户无法选择不加载某功能。

### 1.2 目标

- **可选功能模块化**：显示器设置、fcitx 输入法、语音输入、OCR、截图、虚拟机、文件备份、keyboard remap 拆为独立模块
- **用户按需启用**：通过配置选择要加载的模块
- **独立仓库**：每个模块是独立 git 仓库，通过 submodule 引用
- **声明式注册**：模块自描述提供的能力（bar 按钮、设置页、服务、OSD、bin 脚本）
- **启动时扫描加载**：Quickshell 进程启动时扫描已启用模块

### 1.3 不拆分的核心模块

| 模块 | 理由 |
|------|------|
| Topbar | Shell 骨架，所有模块挂载点 |
| Workspace Overview | 核心导航，依赖 HyprlandData |
| Theme 系统 | Appearance/TuiStyle/Config 是所有 UI 的基础 |
| Lock / Polkit / Notifications / OSD | 基础桌面功能 |
| Settings 框架 | 设置中心本身是核心，模块只注册页面 |

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
│   └── keyboard-remap/               # git submodule → sumika-module-keyboard-remap
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
  ├─ 1. 读取 ~/.config/sumika-shell/quickshell/config.json
  │     获取 modules.enabled 列表
  │
  ├─ 2. 扫描 OMD/modules/*/module.json
  │     过滤出已启用的模块
  │
  ├─ 3. 构建 QML_IMPORT_PATH
  │     核心路径: OMD/quickshell/
  │     模块路径: OMD/modules/<id>/  （每个启用的模块）
  │     export QML_IMPORT_PATH=...
  │
  ├─ 4. 合并配置默认值
  │     核心默认 + 各模块 configDefaults → 用户 config 覆盖
  │
  ├─ 5. 生成模块注册表
  │     收集所有 module.json 的 capabilities
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

```json
{
  "modules": {
    "enabled": ["voice", "ocr", "screenshot", "input-method", "display", "keyboard-remap"],
    "disabled": ["windows-vm", "file-backup"],
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
| P2 | 显示器设置 | `settings/display/*`, `bin/omd-display-config`, `bin/omd-hyprland-monitor-*` | 中 | HyprlandData, Config |
| P2 | Keyboard Remap | `services/KeyboardRemap.qml`, `settings/pages/KeyboardRemapPage.qml`, `share/bin/omarchy-keyboard-*` | 中 | HyprlandData, bar 按钮, OSD |
| P3 | 截图 | `modules/regionSelector/*`, `bin/omd-screenshot` | 中 | GlobalStates, bar 按钮, ScreenshotAction |
| P3 | 输入法 | `services/InputMethod.qml`, `bar/modules/InputMethodButton.qml`, OSD, `settings/pages` | 中 | bar 按钮, OSD, Config |

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