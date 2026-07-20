# Sumika Shell 模块拆分实施文档

> 日期：2026-07-20
> 状态：执行中

## 架构现状

### 当前单体结构

```
quickshell/
├── modules/
│   ├── bar/
│   │   ├── BarContent.qml          # bar 按钮布局（硬编码 9 个按钮）
│   │   ├── BarStatusPopup.qml      # 2800 行弹窗（13 个 content section）
│   │   ├── *Button.qml             # 各按钮组件
│   │   └── ...
│   ├── settings/pages/             # 11 个设置页（已有 qmldir）
│   ├── common/                     # 核心 API + 共享组件
│   ├── overview/                   # 工作区概览
│   ├── lock/                       # 锁屏
│   ├── notificationPopup/          # 通知弹窗
│   ├── onScreenDisplay/            # OSD
│   ├── polkit/                     # PolKit
│   ├── schedulePopup/              # 通知中心
│   └── regionSelector/             # 截图区域选择
├── services/                       # 30+ 个 QML 单例服务
└── scripts/quickshell              # 启动脚本
```

### 关键耦合点

1. **BarContent.qml** — 右侧 9 个按钮硬编码：SysTray、InputMethodButton、AudioButton、WifiButton、ClipboardButton、SessionButton、DisplayButton、ToolsButton、ClockWidget、SidebarIndicators

2. **BarStatusPopup.qml** (2800 行) — 13 个 content section 硬编码：
   - toolsContent (OCR/备份/键盘 — 445-503)
   - inputMethodContent (504-635)
   - keyboardContent (636-677)
   - sessionContent (678-748)
   - xkbContent (749-808)
   - wifiContent (809-1319)
   - bluetoothContent (1320-1361)
   - audioContent (1362-1921)
   - displayContent (1922-2016)
   - batteryContent (2017-2427)
   - notificationsContent (2428-2528)
   - voiceContent (2529-end)

3. **services/** — 所有服务是 `pragma Singleton`，启动时全量创建

4. **settings/pages/qmldir** — 11 个设置页静态注册

## 拆分策略

### 核心原则

1. **不破坏功能**：每步拆完必须 `qs -p apps/omd-bar` 编译通过
2. **渐进式**：先拆最简单的，逐步建立模式
3. **模块目录**：`/home/tetsuya/development/sumika-modules/<module-id>/`
4. **QML import path**：启动脚本动态注入模块路径到 `QML_IMPORT_PATH`
5. **Loader 动态加载**：bar 按钮、弹窗 section、设置页用 `Loader` 加载

### 模块分类（按拆分难度排序）

| 优先级 | 模块 ID | 难度 | 原因 |
|---|---|---|---|
| 1 | file-backup | ⭐ 最易 | 纯 bin 脚本 + TUI，QML 只有 2 个"启动 TUI"按钮 |
| 2 | ocr | ⭐⭐ | bin 脚本 + TUI，但被 ScreenshotAction/RegionSelector 引用 |
| 3 | windows-vm | ⭐⭐ | bin 脚本 + TUI + 1 个设置页 |
| 4 | keyboard-remap | ⭐⭐⭐ | service + bar 按钮 + 弹窗 + 设置页 + bin 脚本 |
| 5 | voice | ⭐⭐⭐ | service + bar 按钮 + 弹窗 + 设置页 + OSD + bin 脚本 |
| 6 | input-method | ⭐⭐⭐ | service + bar 按钮 + 弹窗 + OSD + bin 脚本 |
| 7 | clipboard | ⭐⭐⭐ | 独立进程 + bar 按钮 + bin 脚本 |
| 8 | display | ⭐⭐⭐⭐ | service + bar 按钮 + 弹窗 + 设置页 + bin 脚本 |
| 9 | battery-power | ⭐⭐⭐⭐ | service + bar 图标 + 弹窗 + 设置页 |
| 10 | brightness-gamma | ⭐⭐⭐⭐ | service + bar 按钮 + OSD + 弹窗 |
| 11 | mpris | ⭐⭐⭐⭐ | service + 弹窗 340 行 |
| 12 | systray | ⭐⭐⭐⭐ | service + bar 组件 |
| 13 | session | ⭐⭐⭐⭐⭐ | service + bar 覆盖层 + 弹窗 + bin 脚本 |
| 14 | screenshot | ⭐⭐⭐⭐⭐ | 区域选择器 + bar 按钮 + bin 脚本 + 与 OCR 耦合 |

### 不拆的核心

- Bar 框架（Bar.qml、BarContent.qml 骨架）
- Overview（工作区概览）
- Theme/Config 系统
- 锁屏
- PolKit
- 通知弹窗 + 通知中心
- OSD 框架
- 设置框架
- 核心服务（Audio、HyprlandData、Network、Notifications 等）

## 每个模块的标准结构

```
sumika-modules/<module-id>/
├── module.json              # 模块清单
├── qmldir                   # QML 模块声明
├── services/                # QML 服务（非 singleton，由 Loader 创建）
├── bar/                     # bar 按钮组件
├── popup/                    # BarStatusPopup section 组件
├── settings/                 # 设置页组件
├── osd/                      # OSD 指示器（可选）
├── bin/                      # 可执行脚本
├── scripts/
│   └── install.sh           # 依赖安装
└── config.schema.json        # 配置 schema
```

### module.json 格式

```json
{
  "id": "voice",
  "name": "语音输入",
  "description": "SenseVoice 语音转文字",
  "capabilities": {
    "services": ["VoiceInput"],
    "barButtons": [{ "component": "bar/VoiceButton.qml", "slot": "right", "order": 45 }],
    "popupSections": [{ "type": "voice", "component": "popup/VoicePopup.qml" }],
    "settingsPages": [{ "id": "voice", "title": "语音输入", "component": "settings/VoicePage.qml", "icon": "microphone", "order": 60 }],
    "binScripts": "bin/"
  },
  "configDefaults": {
    "voice": { "enabled": true }
  }
}
```

## 加载机制

### 启动脚本改造

`quickshell/scripts/quickshell` 改为：

```bash
# 1. 扫描模块
MODULES_DIR="$OMD_ROOT/modules"
QML_IMPORT_PATH="$OMD_ROOT/quickshell"

# 2. 检查 sumika-modules 目录
EXT_MODULES_DIR="/home/tetsuya/development/sumika-modules"
if [ -d "$EXT_MODULES_DIR" ]; then
  for mod_dir in "$EXT_MODULES_DIR"/*/; do
    [ -f "$mod_dir/module.json" ] || continue
    mod_id=$(basename "$mod_dir")
    QML_IMPORT_PATH="$QML_IMPORT_PATH:$mod_dir"
    # 注入 bin 到 PATH
    [ -d "$mod_dir/bin" ] && export PATH="$mod_dir/bin:$PATH"
  done
fi

export QML_IMPORT_PATH
exec qs -p "$OMD_ROOT/quickshell" "$@"
```

### BarContent.qml 改造

```qml
// 核心按钮（始终存在）
SysTray { ... }
AudioButton { ... }
WifiButton { ... }
ClockWidget { ... }
SidebarIndicators { ... }

// 模块按钮（动态加载）
Repeater {
    model: ModuleLoader.barButtons
    delegate: Loader {
        required property var modelData
        source: modelData.component
        active: modelData.enabled
        onStatusChanged: if (status === Loader.Error) active = false
    }
}
```

### BarStatusPopup.qml 改造

```qml
// 核心 content（始终存在）
Loader { active: barPopupType === "audio"; sourceComponent: audioContent }
Loader { active: barPopupType === "wifi"; sourceComponent: wifiContent }
// ...

// 模块 content（动态加载）
Repeater {
    model: ModuleLoader.popupSections
    delegate: Loader {
        required property var modelData
        active: barPopupType === modelData.type
        source: modelData.component
        onStatusChanged: if (status === Loader.Error) active = false
    }
}
```

### 配置系统

```json
{
  "modules": {
    "disabled": ["windows-vm"],
    "barButtonOrder": { "voice": 45, "input-method": 50 }
  }
}
```

黑名单制：模块目录存在即默认启用，用户在 `disabled` 中声明禁用。

## 实施步骤

### Phase 0：基础设施
1. 创建 `ModuleLoader.qml`（模块加载器单例）
2. 改造启动脚本（扫描模块、注入 import path）
3. 改造 `BarContent.qml`（核心按钮 + 动态 Repeater）
4. 改造 `BarStatusPopup.qml`（核心 content + 动态 Repeater）
5. 改造 `SettingsDialog.qml`（核心页 + 动态 Repeater）
6. 改造 `Config.qml`（支持模块配置合并）

### Phase 1：第一个模块（file-backup）
7. 创建 `sumika-modules/file-backup/` 目录结构
8. 移动 `bin/omd-backup`、`bin/omd-settings-backup-tui`、`bin/omd-launch-settings-backup-tui`
9. 从 `BarStatusPopup.qml` 提取 backup 按钮到模块
10. 从 `OverviewPage.qml` 提取 backup 设置入口到模块
11. 编写 `module.json` + `qmldir`
12. 测试编译 + 运行

### Phase 2-14：逐个拆分剩余模块
每个模块重复 Phase 1 的步骤，但增加该模块特有的组件提取（service、bar button、popup section、settings page、OSD 等）。

### 最终验证
- 全部 4 个 Quickshell 进程编译通过
- 所有功能正常运行
- 禁用模块后对应 UI 消失
- 启用后恢复