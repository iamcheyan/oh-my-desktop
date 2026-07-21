# 模块系统现状报告

> 日期：2026-07-21
> 范围：Sumika Shell 插件/模块的行为逻辑与控制方式
> 版本：module-split 分支 + 注册审计修复

---

## 一、架构概览

```
sumika.json (chezmoi 管理)
    │ modules.enabled: true/false
    │ modules.disabled: ["module-id", ...]    ← per-module 禁用
    ▼
ModuleLoader.qml (QML Singleton)
    ├── modulesEnabled          ← 读取 Config.options.modules.enabled
    ├── isEnabled(moduleId)     ← 检查 modules.enabled + modules.disabled
    ├── leftBarButtons          ← 左侧所有按钮（registry.barButtons, slot:left）
    ├── rightBarButtons         ← 右侧所有按钮（registry.barButtons, slot:right）
    ├── barButtons              ← @deprecated rightBarButtons 别名
    ├── popupSections           ← 动态弹窗 section（来自注册表）
    ├── settingsPages           ← 动态设置页（来自注册表）
    └── activeModuleIds         ← 已启用的模块 ID 列表

```
quickshell/scripts/quickshell
  ├─ 添加 QML_IMPORT_PATH / PATH（外部模块存在时）
  ├─ 无条件生成注册表：
  │   ├── 扫描 builtin 清单 → 合并 barButtons (alwaysShow标记)
  │   ├── modules.enabled != false 时扫描外部模块 → 合并 popupSections/barButtons/settingsPages
  │   ├── jq 不可用时写入硬编码 fallback（6 个 alwaysShow 核心按钮）
  │   ├── 原子写入 $XDG_RUNTIME_DIR/sumika-shell/modules.json
  │   └── 日志输出按钮/弹窗/设置页数量
  └── 启动 Quickshell
```
quickshell/registry/builtin/bar.json (内置清单)
    └── 12 个核心按钮（AppLauncher, ActiveWindow, SysTray, Audio, Wifi,
         InputMethod, Clipboard, Session, Display, Tools, Clock, SidebarIndicators）
        ├── alwaysShow: true  → Audio, Wifi, Clock, SidebarIndicators, AppLauncher, ActiveWindow
        └── alwaysShow: false → SysTray, InputMethod, Clipboard, Session, Display, Tools
```

### 控制链

```
chezmoi sumika.json
  └─ modules.enabled: false
       ├─ ModuleLoader.modulesEnabled → false
       │   ├─ leftBarButtons → 只返回 alwaysShow=true 的按钮
       │   ├─ rightBarButtons → 只返回 alwaysShow=true 的按钮
       │   ├─ popupSections → []（无模块提供）
       │   └─ settingsPages → []（无模块提供）
       ├─ 启动脚本不生成注册表 → 删除遗留注册表
       └─ 锁屏 Lock {} 组件仍然创建（核心 UI，不是可选插件）
```

### 配置定义 (`Config.qml:354`)

```qml
property JsonObject modules: JsonObject {
    property bool enabled: true                          // 总开关
    property list disabled: []                           // per-module 禁用列表
    property JsonObject barButtonOrder: JsonObject {}    // 预留：按钮排序
}
```

---

## 二、Master Switch：`modules.enabled`

### 控制方式

| 值 | 效果 |
|---|---|
| `true`（默认） | 所有模块功能可用，注册表生成，动态加载 |
| `false` | 无模块功能，仅内置 alwaysShow 按钮可见 |

### 影响范围

**`modules.enabled: false` 时隐藏或不可用的内容：**

| 组件 | 位置 | 控制机制 |
|---|---|---|
| SysTray | 右侧按钮区 | `alwaysShow: false` → 被过滤 |
| InputMethodButton | 右侧按钮区 | 同上 |
| ClipboardButton | 右侧按钮区 | 同上 |
| SessionButton | 右侧按钮区 | 同上 |
| DisplayButton | 右侧按钮区 | 同上 |
| ToolsButton | 右侧按钮区 | 同上 |
| 外部模块动态按钮 | 右侧 Repeater | `isEnabled()` → false |
| 外部模块动态弹窗 | BarStatusPopup TuiShell Repeater | `isEnabled()` → false |
| 外部模块设置页 | SettingsDialog Repeater | `isEnabled()` → false |
| LOCK 按钮 | 电池弹窗 SESSION 区 | `visible: ModuleLoader.modulesEnabled` |

**`modules.enabled: false` 时仍然存在的功能：**

| 组件 | 原因 |
|---|---|
| AppLauncherButton | `alwaysShow: true` |
| ActiveWindow | `alwaysShow: true` |
| AudioButton | `alwaysShow: true` |
| WifiButton | `alwaysShow: true` |
| ClockWidget | `alwaysShow: true` |
| SidebarIndicators | `alwaysShow: true` |
| 通知弹窗 | 核心功能 |
| 锁屏 Lock {} | 核心 UI 组件，不是可选插件 |
| 锁屏扫描的 QML import | 启动脚本无条件添加模块目录和 symlink |

---

## 三、Per-Module 禁用：`modules.disabled`

### 配置方法

```json
{
  "modules": {
    "enabled": true,
    "disabled": ["mpris", "systray"]
  }
}
```

### `ModuleLoader.isEnabled(moduleId)`

```qml
function isEnabled(moduleId) {
    if (!modulesEnabled) return false
    const disabled = Config.options.modules?.disabled ?? []
    if (Array.isArray(disabled) && disabled.indexOf(moduleId) >= 0) return false
    return true
}
```

### 效果

|
 情景 | showMediaControls | popupSections | 右侧按钮 |
|---|---|---|---|
| enabled:true, disabled:[] | false（模块提供） | 加载 mpris section | 全部显示 |
| enabled:true, disabled:["mpris"] | true（内嵌回退） | 无 mpris section | 全部显示 |
| enabled:false | true（内嵌回退） | [] | 仅 alwaysShow 按钮 |

---

## 四、按钮注册系统

### 内置清单 (`quickshell/registry/builtin/bar.json`)

所有核心按钮通过单一清单文件注册：

| id | slot | alwaysShow | 文件 |
|---|---|---|---|
| appLauncher | left | true | `modules/bar/AppLauncherButton.qml` |
| activeWindow | left | true | `modules/bar/ActiveWindow.qml` |
| systray | right | false | `modules/bar/SysTray.qml` |
| inputMethod | right | false | `modules/bar/modules/InputMethodButton.qml` |
| audio | right | true | `modules/bar/modules/AudioButton.qml` |
| wifi | right | true | `modules/bar/modules/WifiButton.qml` |
| clipboard | right | false | `modules/bar/modules/ClipboardButton.qml` |
| session | right | false | `modules/bar/modules/SessionButton.qml` |
| display | right | false | `modules/bar/modules/DisplayButton.qml` |
| tools | right | false | `modules/bar/modules/ToolsButton.qml` |
| clock | right | true | `modules/bar/ClockWidget.qml` |
| sidebarIndicators | right | true | `modules/bar/SidebarIndicators.qml` |

### 右侧按钮加载逻辑 (`ModuleLoader._filterBarButtons`)

```qml
function _filterBarButtons(slot) {
    const buttons = _registry.barButtons ?? []
    const result = []
    for (var i = 0; i < buttons.length; i++) {
        var b = buttons[i]
        if (b.slot !== slot) continue
        // alwaysShow 按钮不受模块开关影响
        if (b.alwaysShow) {
            result.push(b)
        } else if (loader.isEnabled(b.moduleId)) {
            result.push(b)
        }
    }
    result.sort((a, b) => (a.order ?? 100) - (b.order ?? 100))
    return result
}
```

### 右侧按钮区现在改为纯 Repeater

```qml
RowLayout {
    Repeater {
        model: ModuleLoader.rightBarButtons
        delegate: Loader {
            source: modelData.component
            active: true
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
```

**不再有硬编码的 SysTray/Audio/Wifi 等直接 import 和实例化。**

### 顺序控制

按钮在清单中声明的 `order` 决定显示顺序。外部模块声明的 barButtons 也参与排序。

---

## 五、弹窗 Section 通用挂载点

### 结构变化

原本 `popupSections` Repeater 硬编码在 `audioContent` Component 内部：

```
TuiShell {
    Loader { id: contentLoader }  ← 加载 audioContent/wifiContent 等
    // （无 section 挂载点）
}

audioContent Component {
    ColumnLayout {
        ... header ...
        Repeater { model: ModuleLoader.popupSections } ← 旧：只在音频弹窗
        ... slider ...
    }
}
```

现在移至 `TuiShell` 内通用位置：

```
TuiShell {
    ColumnLayout {
        Loader { id: contentLoader }
        Repeater { model: ModuleLoader.popupSections }  ← 新：所有弹窗类型可见
    }
}
```

每个 popup section 通过 `root.activeType === modelData.type` 控制显隐，仅在匹配的弹窗类型中加载。

### 内嵌媒体回退

`showMediaControls` 现在由 `ModuleLoader.isEnabled("mpris")` 控制：

```qml
readonly property bool showMediaControls: activePlayer !== null && !ModuleLoader.isEnabled("mpris")
```

确保当 mpris 模块被禁用或全局模块关闭时，内嵌媒体控件自动显示。

---

## 六、设置页动态集成

### SettingsDialog 变化

`SettingsDialog.qml` 现在通过 `ModuleLoader.settingsPages` 合并动态设置页：

```qml
readonly property var pages: {
    var ps = []
    for (var i = 0; i < primaryPages.length; i++) ps.push(primaryPages[i])
    var modPages = ModuleLoader.settingsPages
    for (var j = 0; j < modPages.length; j++) {
        var p = modPages[j]
        if (p.id) {
            ps.push({ key: p.id, icon: p.icon ?? "extension", title: p.title ?? p.id, ... })
        }
    }
    return ps
}
```

### 懒加载 Component

模块设置页通过 `Qt.createComponent()` 懒加载，首次导航到该页时才创建 Component：

```qml
function _ensureModulePage(pageId) {
    if (pageId in _modulePageComponents) return
    var modPages = ModuleLoader.settingsPages
    for (var i = 0; i < modPages.length; i++) {
        var p = modPages[i]
        if (p.id !== pageId && (!p.aliases || p.aliases.indexOf(pageId) < 0)) continue
        var comp = Qt.createComponent(p.component)
        if (comp.status === Component.Error) {
            console.warn("[Settings] Failed to load module page:", p.id, comp.errorString())
            return
        }
        _modulePageComponents[p.id] = comp
        // 别名映射
    }
}
```

---

## 七、注册表系统

### 路径

```
旧: /tmp/sumika-module-registry.json
新: $XDG_RUNTIME_DIR/sumika-shell/modules.json
    → /run/user/1000/sumika-shell/modules.json
```

### 原子写入

启动脚本使用 `mktemp` + `mv` 确保注册表不会被部分写入。

### schemaVersion 校验
### 内置清单合并

启动脚本在外部模块扫描之前合并 `quickshell/registry/builtin/` 下的 JSON 文件：


```
jq 合并：
  .modules += [{ id, path, builtin: true }]
  .barButtons += (capabilities.barButtons // [] | map({ +moduleId, component: file:// resolve }))
```

---

## 八、锁屏（特殊核心组件）

### 为什么锁屏不服从 modules.enabled

锁屏 (`Lock {}`) 在 `shell.qml` 中直接 import 和实例化，不经过 ModuleLoader，不受 `modules.enabled` 控制。原因：

1. **锁屏是安全组件** — 如果禁用了，任何用户都能绕过锁屏
2. **锁屏是 Quickshell 的 compositor 协议** — 使用 `ext-session-lock-v1` Wayland 协议，必须在 compositor 会话中存在
3. **锁屏需要响应 Idle 超时和 suspend 事件** — 即使在"简洁模式"下也需要锁屏能力

### 锁屏的控制方式

锁屏通过 `Config.options.lock.*` 控制行为，不通过 `modules.enabled`。

### LOCK 按钮 vs 锁屏功能

电池弹窗里的 LOCK 按钮受 `modules.enabled` 控制——它只是一个快捷操作入口。但锁屏功能本身始终存在。

---

## 九、外部模块清单

| 模块 ID | 弹窗(s) | 设置页 | 服务 | 备注 |
|---|---|---|---|---|
| battery-power | battery | Power & Battery | Battery, PowerProfiles | 电池图标+电源菜单在核心 |
| brightness-gamma | — | — | Brightness, Hyprsunset | OSD 在核心 |
| clipboard | — | — | Cliphist | 按钮在核心 |
| display | display | Display Settings | Brightness | 按钮在核心 |
| file-backup | file-backup | 备份 | — | |
| input-method | inputMethod | — | InputMethod | 按钮在核心 |
| keyboard-remap | keyboard | Keyboard Remap | KeyboardRemap | 按钮在核心 |
| lock | — | — | — | 特殊：直接 import，不受 modules.enabled 控制 |
| mpris | audio | — | MprisController, TrackArt | 弹窗已提取到模块；isEnabled("mpris")=false 时回退到内嵌版本 |
| ocr | ocr | OCR 识别 | — | |
| screenshot | — | — | — | bin 在核心 |
| session | session | — | Session | 按钮在核心 |
| systray | — | — | TrayService | 按钮在核心 |
| voice | voice | Voice Input | VoiceInput | 按钮在核心 |
| windows-vm | windows-vm | Windows VM | — | |
| popup-components | — | — | — | 共享 UI 组件库 |

---

## 十、控制方式总结

### 配置

| 配置 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `modules.enabled` | boolean | `true` | 主开关 |
| `modules.disabled` | string[] | `[]` | 禁用的模块 ID 列表 |
| `modules.barButtonOrder` | object | `{}` | 预留：按钮排序 |

### 修改方法

```sh
chezmoi edit ~/.config/sumika-shell/sumika.json
# 修改 modules.enabled / modules.disabled
chezmoi apply --force
omd-restart
```

### 查看状态

```sh
omd-modules list
# MODULE                STATUS     FILES  CAPABILITIES
# ──────                ──────     ─────  ───────────
# mpris                 enabled    14     popup(1)
# battery-power         enabled    22     popup(1) settings(1)
# clipboard             disabled   8      —
```

### 效果速查表

| 场景 | modules.enabled: false | modules.enabled: true, disabled:[] | modules.enabled: true, disabled:["mpris"] |
|---|---|---|---|
| AppLauncher / ActiveWindow | 显示（alwaysShow） | 显示 | 显示 |
| Audio / WiFi / Clock / Sidebar | 显示（alwaysShow） | 显示 | 显示 |
| 右侧模块按钮 | 全部隐藏 | 全部显示 | 全部显示 |
| mpris 媒体弹窗 | 无（内嵌回退） | 模块提供 | 无（内嵌回退） |
| 其他外部模块弹窗 | 不可用 | 可用 | 可用 |
| 设置页模块导航 | 不可用 | 可用 | 可用 |
| LOCK 快捷按钮 | 隐藏 | 显示 | 显示 |
| 自动锁屏（idle/suspend） | 正常工作 | 正常工作 | 正常工作 |
| 锁屏功能 | 完整可用 | 完整可用 | 完整可用 |

---

## 十一、后续改进方向

1. **服务懒加载** — 模块禁用时应停止对应服务，不只是隐藏 UI
2. **barButtonOrder 实现** — 配置中存在但未使用的排序功能
3. **lock 模块迁移** — 允许 lock 模块通过 modules.enabled 控制（需要安全设计讨论）
4. **注册表热重载** — 模块动态启用/禁用时无需 omd-restart
5. **ModulesPage 实时性** — 设置页中添加/移除模块后即时反映，无需重启
6. **内置按钮迁移到外部模块** — 逐步将 builtin 按钮转换为自包含的外部模块（含服务迁移）
