# 模块系统现状报告

> 日期：2026-07-21
> 范围：Sumika Shell 插件/模块的行为逻辑与控制方式

---

## 一、架构概览

```
sumika.json (chezmoi 管理)
    │ modules.enabled: true/false
    ▼
ModuleLoader.qml (QML Singleton)
    ├── modulesEnabled          ← 读取 Config.options.modules.enabled
    ├── leftBarModules          ← 左侧注册区（AppLauncher + ActiveWindow + ext slot:left）
    ├── barButtons              ← 右侧动态模块按钮（来自注册表）
    ├── popupSections           ← 动态弹窗 section（来自注册表）
    ├── settingsPages           ← 动态设置页（来自注册表）
    └── isEnabled(moduleId)     ← 过滤函数
        └── 当前实现：完全由 master switch 控制，无 per-module 开关

quickshell/scripts/quickshell (启动脚本)
    ├── SUMIKA_MODULES_HOME → 扫描 module.json
    ├── 总是添加 QML_IMPORT_PATH + 创建 lock symlink
    └── modules.enabled = true 时才生成注册表
```

### 控制链

```
chezmoi sumika.json
  └─ modules.enabled: false
       ├─ ModuleLoader.modulesEnabled → false → 所有模块属性返回 []
       ├─ 启动脚本不生成注册表 → /tmp/sumika-module-registry.json 不存在
       └─ 锁屏 Lock {} 组件仍然创建（核心 UI，不是可选插件）
```

### 配置定义 (`Config.qml:354`)

```qml
property JsonObject modules: JsonObject {
    property bool enabled: true                          // 总开关
    property JsonObject barButtonOrder: JsonObject {}    // 预留：按钮排序
}
```

当前 `sumika.json` 状态：

```json
{
  "modules": {
    "barButtonOrder": {},
    "enabled": false
  }
}
```

---

## 二、Master Switch：`modules.enabled`

### 控制方式

| 值 | 效果 |
|---|---|
| `true`（默认） | 所有模块功能可用，注册表生成，动态加载 |
| `false` | 所有模块功能隐藏，注册表不生成 |

### 影响范围

**`modules.enabled: false` 时隐藏的内容：**

| 组件 | 位置 | 控制机制 |
|---|---|---|
| AppLauncherButton | 左侧，Workspaces 右侧 | `ModuleLoader.leftBarModules` → 返回 `[]` |
| ActiveWindow | 左侧，AppLauncher 右侧 | 同上 |
| SysTray | 右侧按钮区 | `visible: ModuleLoader.modulesEnabled` |
| InputMethodButton | 右侧按钮区 | 同上 |
| ClipboardButton | 右侧按钮区 | 同上 |
| SessionButton | 右侧按钮区 | 同上 |
| DisplayButton | 右侧按钮区 | 同上 |
| ToolsButton | 右侧按钮区 | 同上 |
| 外部模块动态按钮 | 右侧 Repeater | `ModuleLoader.barButtons` → 返回 `[]` |
| 外部模块动态弹窗 | BarStatusPopup Repeater | `ModuleLoader.popupSections` → 返回 `[]` |
| 外部模块设置页 | SettingsDialog Repeater | `ModuleLoader.settingsPages` → 返回 `[]` |
| LOCK 按钮 | 电池弹窗 SESSION 区 | `visible: ModuleLoader.modulesEnabled` |

**`modules.enabled: false` 时仍然存在的功能：**

| 组件 | 原因 |
|---|---|
| AudioButton | 核心功能，永远显示 |
| WifiButton | 核心功能，永远显示 |
| ClockWidget | 核心功能，永远显示 |
| SidebarIndicators | 核心功能，永远显示 |
| 通知弹窗 | 核心功能 |
| 锁屏 Lock {} | 核心 UI 组件，不是可选插件 |
| 锁屏扫描的 QML import | 启动脚本无条件添加模块目录和 symlink |

---

## 三、左侧模块注册区（本次新增）

`BarContent.qml` 的 `leftSectionRowLayout` 中 `Workspaces` 之后有一个 `Repeater`：

```qml
Repeater {
    model: ModuleLoader.leftBarModules
    delegate: Loader {
        source: modelData.component
        // 动态加载
    }
}
```

### 当前注册的两个内置模块

`ModuleLoader.leftBarModules` 返回：

```js
[
    { component: Qt.resolvedUrl("../modules/bar/AppLauncherButton.qml"), id: "appLauncher", name: "Applications" },
    { component: Qt.resolvedUrl("../modules/bar/ActiveWindow.qml"), id: "activeWindow", name: "Active Window" }
]
```

### 外部模块左侧扩展

外部 module.json 的 `barButtons` 中声明 `"slot": "left"` 的按钮会被附加到数组末尾。当前没有外部模块使用此 slot。

### 顺序

硬编码内置模块在前，外部 slot:left 在后。内置模块的相对顺序（AppLauncher → ActiveWindow）不可配置。

---

## 四、右侧按钮区

### 静态硬编码按钮（永远显示）

```
[SysTray] [InputMethodButton] ← 只当 enabled 时 visible
                                 ─── 分割线 ───
[AudioButton] [WifiButton]     ← 永远显示
                                 ─── 分割线 ───
[ClipboardButton] [SessionButton] [DisplayButton] [ToolsButton] ← 只当 enabled 时 visible
                                 ─── 分割线 ───
[ClockWidget] [SidebarIndicators] ← 永远显示
                                 ─── 分割线 ───
<Repeater: ModuleLoader.barButtons> ← 外部模块动态加载
```

### 行为的实际问题

这几个按钮（SysTray, InputMethodButton, ClipboardButton, SessionButton, DisplayButton, ToolsButton）当前只通过 `visible: ModuleLoader.modulesEnabled` 控制显隐，**没有 per-module 开关**。它们对应的功能服务（TrayService, InputMethod, Cliphist, Session, Display, KeyboardRemap 等）在 `modules.enabled: false` 时仍然在后台运行——只是按钮隐藏了。

这是已知的设计 gap，后续需要：
1. 给每个右侧按钮分配 moduleId
2. ModuleLoader.isEnabled() 支持 per-module 配置
3. 服务懒加载

---

## 五、锁屏（特殊核心组件）

### 为什么锁屏不服从 modules.enabled

锁屏 (`Lock {}`) 在 `shell.qml` 中直接 import 和实例化：

```qml
import qs.modules.lock
...
Lock {}
```

它不经过 ModuleLoader，不受 `modules.enabled` 控制。原因：

1. **锁屏是安全组件** — 如果禁用了，任何用户都能绕过锁屏
2. **锁屏是 Quickshell 的 compositor 协议** — 使用 `ext-session-lock-v1` Wayland 协议，必须在 compositor 会话中存在
3. **锁屏需要响应 Idle 超时和 suspend 事件** — 即使在"简洁模式"下也需要锁屏能力

### 锁屏的控制方式

锁屏通过 `Config.options.lock.*` 控制行为，不通过 `modules.enabled`：

| 配置项 | 默认值 | 说明 |
|---|---|---|
| `lock.launchOnStartup` | `false` | 启动时是否立即锁屏 |
| `lock.blur.enable` | `true` | 锁屏模糊效果 |
| `lock.blur.radius` | `100` | 模糊半径 |
| `lock.centerClock` | `true` | 居中时钟 |
| `lock.showLockedText` | `true` | 显示"已锁定"文字 |
| `lock.security.unlockKeyring` | `true` | 解锁时是否解锁 keyring |
| `lock.security.requirePasswordToPower` | `false` | 关机/重启是否需要密码 |
| `lock.materialShapeChars` | `true` | 材料设计锁屏字符形状 |

### LOCK 按钮 vs 锁屏功能

**电池弹窗里的 LOCK 按钮**（BarStatusPopup.qml:2268）受 `modules.enabled` 控制——它只是一个快捷操作入口。但锁屏功能本身（Lock.qml + LockService + LockSurface）始终存在，不受 modules.enabled 影响。

这意味着：
- `modules.enabled: false` → LOCK 按钮隐藏，但系统仍然会自动锁屏（idle timeout、suspend 前）
- `modules.enabled: true` → LOCK 按钮可见，用户可手动触发锁屏

### LockService 注册机制

`Lock.qml` 通过 `LockService.register()` 在 Component.onCompleted 时注册锁屏回调：

```qml
Component.onCompleted: LockService.register(() => root.lock())
Component.onDestruction: LockService.register(null)
```

`Session.lock()` 调用 `LockService.lock()`，优先调用已注册的 handler，否则直接设置 `GlobalStates.screenLocked = true`。

---

## 六、外部模块系统（sumika-modules）

### 发现机制

启动脚本 `quickshell/scripts/quickshell` 扫描 `~/development/sumika-modules/*/module.json`：

1. 无条件：添加每个模块目录到 `QML_IMPORT_PATH`
2. 无条件：为 `lock` 等核心模块创建 `quickshell/modules/<name>` symlink（用于 scanner 解析）
3. 有条件（`modules.enabled = true`）：生成注册表 `/tmp/sumika-module-registry.json`

### 注册表结构

```json
{
  "modules": [
    { "id": "battery-power", "path": "/home/tetsuya/development/sumika-modules/battery-power" }
  ],
  "barButtons": [],
  "popupSections": [
    { "type": "battery", "component": "file://.../BatteryPopup.qml", "moduleId": "battery-power" }
  ],
  "settingsPages": [
    { "id": "power", "title": "Power & Battery", "component": "file://.../PowerPage.qml", "moduleId": "battery-power" }
  ]
}
```

### ModuleLoader 消费

ModuleLoader 的 Process 异步读取注册表 JSON，解析后暴露给 Repeater：

| 属性 | 来源 | 消费方 |
|---|---|---|
| `barButtons` | registry.barButtons | BarContent.qml 右侧 Repeater |
| `leftBarModules` | registry.barButtons (slot: left) + 内置 | BarContent.qml 左侧 Repeater |
| `popupSections` | registry.popupSections | BarStatusPopup.qml 弹窗 Repeater |
| `settingsPages` | registry.settingsPages | SettingsDialog.qml 导航 Repeater |
| `activeModuleIds` | registry.modules | ModulesPage.qml 设置页 |

### 所有外部模块清单

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
| mpris | audio | — | MprisController, TrackArt | 弹窗已提取到模块；modules.enabled:false 时回退到内嵌版本 |
| ocr | ocr | OCR 识别 | — | |
| screenshot | — | — | — | bin 在核心 |
| session | session | — | Session | 按钮在核心 |
| systray | — | — | TrayService | 按钮在核心 |
| voice | voice | Voice Input | VoiceInput | 按钮在核心 |
| windows-vm | windows-vm | Windows VM | — | |
| popup-components | — | — | — | 共享 UI 组件库 |

---

## 七、控制方式总结

### 通过 chezmoi 配置（`~/.config/sumika-shell/sumika.json`）

```json
{
  "modules": {
    "enabled": false          // ← 一键关闭所有模块功能
  },
  "lock": {                   // ← 锁屏行为配置（独立于 modules）
    "launchOnStartup": false,
    "centerClock": true
  }
}
```

### 修改方法

```sh
# 编辑配置
chezmoi edit ~/.config/sumika-shell/sumika.json
# 修改 modules.enabled → true/false
# 然后
chezmoi apply
omd-restart
```

### 效果速查表

| 场景 | modules.enabled: false | modules.enabled: true |
|---|---|---|
| AppLauncher 按钮 | 隐藏 | 显示 |
| ActiveWindow 标题 | 隐藏 | 显示 |
| 右侧模块按钮 | 全部隐藏 | 全部显示（受 per-module 控制） |
| 外部模块弹窗 | 不可用（回退到核心内嵌版本） | 可用（模块版本替代内嵌版本） |
| 设置页模块导航 | 不可用 | 可用 |
| LOCK 快捷按钮（电池弹窗） | 隐藏 | 显示 |
| 自动锁屏（idle/suspend） | 正常工作 | 正常工作 |
| 锁屏功能 | 完整可用 | 完整可用 |
| Audio/WiFi/时钟 | 正常 | 正常 |

---

## 八、后续改进方向

1. **Per-module 开关** — `isEnabled(moduleId)` 目前只检查 master switch，未检查 per-module 配置
2. **右侧按钮模块化** — 6 个硬编码右侧按钮（SysTray, InputMethod, Clipboard, Session, Display, Tools）应该迁移到外部模块，通过 module.json 的 barButtons 注册
3. **服务懒加载** — 模块禁用时应停止对应服务，不只是隐藏按钮
4. **barButtonOrder 实现** — 配置中存在但未使用的排序功能
5. **lock 模块移动到 modules.enabled 控制** — 允许当 `modules.enabled: false` 时也隐藏锁屏功能（当前保留为安全设计，需要讨论后再改）


## 九、MPRIS 媒体控制模块提取

### 提取方案

媒体播放控制（专辑封面、曲目标题、播放/暂停/上一首/下一首）已从 `BarStatusPopup.qml` 的 `audioContent` 内嵌实现提取到外部模块 `sumika-modules/mpris/popup/MprisPopup.qml`。

### 模块注册

`mpris/module.json` 中的 `popupSections` 注册 `"type": "audio"`，表示此弹窗段附加在音频弹窗内。

### 双状态切换

| modules.enabled | 媒体控制来源 |
|---|---|
| `true` | `MprisPopup.qml`（通过 ModuleLoader.popupSections Repeater 动态加载） |
| `false` | 内嵌在 `BarStatusPopup.qml` 的 `audioContent`（`showMediaControls` 属性通过 `&& !ModuleLoader.modulesEnabled` 回退） |

### 机制

`BarStatusPopup.qml` 的 `audioContent` 中插入了 `Repeater` 以加载 `ModuleLoader.popupSections`：

```qml
Repeater {
    model: ModuleLoader.popupSections
    delegate: Loader {
        required property var modelData
        active: root.activeType === modelData.type
        source: active ? modelData.component : ""
    }
}
```

当模块版本启用时，内嵌版本的 `showMediaControls` 被设为 `false` 以隐藏内嵌 UI。这是第一个使用此机制的模块弹窗。