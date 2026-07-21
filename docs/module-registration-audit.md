# Sumika Shell 模块与插件注册机制审查

> 审查日期：2026-07-21  
> 审查分支：`module-split`  
> 参考文档：`docs/module-system-status.md`、`docs/module-system-design.md`  
> 审查范围：OMD 核心仓库、`~/development/sumika-modules/`、启动注册表、Bar、Popup、Settings、应用启动器、锁屏、MPRIS 媒体模块

## 1. 结论

当前系统还不是“插件通过清单完整注册到桌面”的架构，而是一个过渡态：

1. 外部模块有 `module.json`，启动时也会生成注册表。
2. 注册表目前只真正收集 `barButtons`、`popupSections`、`settingsPages`。
3. 现有 16 个模块中，`barButtons` 总数为 **0**；因此顶栏按钮仍全部由核心代码决定。
4. 清单声明的 13 个 `services`、1 个 `apps` 和多个 `binScripts` 不会进入运行时注册表，也不会控制服务或进程生命周期。
5. Settings 当前没有消费 `ModuleLoader.settingsPages`，文档所述“动态设置页”与实际代码不一致。
6. 应用启动器、锁屏入口、媒体播放器、剪贴板、会话、显示器、输入法、托盘等仍存在硬编码、重复实现或跨目录所有权。
7. 目前“禁用模块”主要只是隐藏部分 UI；它不是独立插件的启停，更不能保证服务停止、快捷键注销、进程不启动。

因此，现在继续单纯把文件移动到 `sumika-modules`，会扩大跨仓库依赖，却不会自然得到可安装、可启停、可卸载的插件系统。下一阶段应先统一**注册契约和生命周期**，再继续物理拆分。

---

## 2. 当前目录与职责

### 2.1 OMD 核心仓库

当前核心仍持有：

- Quickshell 进程入口：`apps/omd-*`
- Bar 框架及多数按钮：`quickshell/modules/bar/`
- Popup 总容器及大量业务内容：`BarStatusPopup.qml`
- Settings 框架和固定页面：`quickshell/modules/settings/`
- 多数被外部模块声明的服务：`quickshell/services/`
- Overview、通知、OSD、Polkit 等桌面基础设施

### 2.2 外部模块目录

`~/development/sumika-modules/` 当前有 16 个模块：

`battery-power`、`brightness-gamma`、`clipboard`、`display`、`file-backup`、`input-method`、`keyboard-remap`、`lock`、`mpris`、`ocr`、`popup-components`、`screenshot`、`session`、`systray`、`voice`、`windows-vm`。

这些目录目前混合了三种不同状态：

1. **真正持有实现**：例如 `session/services/Session.qml`。
2. **只持有 UI，服务仍在核心**：例如 `mpris` 的 Popup 在插件目录，但 `MprisController.qml` 和 `TrackArt.qml` 仍在核心。
3. **清单只描述能力，实际能力没有接入加载器**：例如 `apps`、`services`、`binScripts`。

### 2.3 重复所有权示例

剪贴板同时存在：

- `apps/omd-clipboard/`
- `~/development/sumika-modules/clipboard/apps/omd-clipboard/`
- 核心 Bar 中的 `ClipboardButton.qml`
- 插件中的 `clipboard/bar/ClipboardButton.qml`

这会产生两个问题：无法明确哪个目录是唯一源码；修复一侧后另一侧可能继续运行旧实现。

服务也存在同样问题。以下插件声明的服务仍由核心目录提供：

| 插件 | 清单声明 | 实际仍在核心 |
|---|---|---|
| battery-power | Battery, PowerProfiles | 是 |
| brightness-gamma | Brightness, Hyprsunset | 是 |
| display | Brightness | 是 |
| input-method | InputMethod | 是 |
| keyboard-remap | KeyboardRemap | 是 |
| mpris | MprisController, TrackArt | 是 |
| systray | TrayService | 是 |
| voice | VoiceInput | 是 |

这说明清单中的 `services` 目前是说明文字，不是可执行注册。

---

## 3. 当前注册链路

实际启动链路如下：

```text
quickshell/scripts/quickshell
  ├─ 扫描 ~/development/sumika-modules/*/module.json
  ├─ 无条件把所有插件加入 QML_IMPORT_PATH / PATH
  ├─ 对名字恰好为 lock 的目录创建特殊 symlink
  ├─ modules.enabled != false 时生成 /tmp/sumika-module-registry.json
  │    └─ 只合并 barButtons / popupSections / settingsPages
  └─ 启动 Quickshell

ModuleLoader.qml
  ├─ 启动时读取一次注册表
  ├─ 暴露 barButtons / popupSections / settingsPages
  ├─ 内部硬编码 AppLauncherButton / ActiveWindow
  └─ isEnabled(id) 只检查总开关
```

当前清单统计：

| 能力 | 声明数量 | 注册表是否收集 | 消费情况 |
|---|---:|---|---|
| barButtons | 0 | 是 | 无实际插件按钮可加载 |
| popupSections | 10 | 是 | 只在 Audio Popup 内有动态 Repeater |
| settingsPages | 7 | 是 | 当前 SettingsDialog 未消费 |
| services | 13 | 否 | 多数由核心直接 import |
| apps | 1 | 否 | 不控制独立进程 |
| binScripts | 多个 | 否 | 仅通过把整个目录加入 PATH 间接暴露 |

---

## 4. 主要问题

### P0：清单不是唯一注册源

`BarContent.qml` 仍直接实例化：

- `SysTray`
- `InputMethodButton`
- `AudioButton`
- `WifiButton`
- `ClipboardButton`
- `SessionButton`
- `DisplayButton`
- `ToolsButton`
- `ClockWidget`
- `SidebarIndicators`

动态 `barButtons` 只被追加在最后，且当前清单没有任何 `barButtons`。这意味着：

- 按钮是否存在由核心源码决定，而不是插件安装/启用状态决定。
- 插件不能控制自己的入口和顺序。
- `barButtonOrder` 无法统一影响静态按钮。
- 删除插件后可能留下一个仍可点击但后端不存在的按钮。

`ModuleLoader.leftBarModules` 也直接写死了 `AppLauncherButton.qml` 和 `ActiveWindow.qml`。这只是把硬编码从 `BarContent` 移到了加载器，并不属于注册。

### P0：插件启用不是逐插件启用

`ModuleLoader.isEnabled(moduleId)` 当前忽略 `moduleId`，只返回总开关状态。

更严重的是，`ModulesPage.qml` 中每个模块行的按钮实际调用：

```qml
onClicked: page.setMasterEnabled(!page.masterEnabled)
```

也就是点击任意一个插件的开关，切换的是**全部插件总开关**。界面显示为逐插件管理，实际行为并不是。

`bin/omd-modules list` 也把所有被发现目录固定显示为 `enabled`，没有 installed/enabled/loaded 三种状态的区别。

### P0：Settings 动态页面未接入

`SettingsDialog.qml` 当前使用固定的 `primaryPages`、`normalizePage()` 和 `pageComponent()` 条件分支，没有引用 `ModuleLoader.settingsPages`。

因此，外部清单中的 7 个 `settingsPages` 即使进入注册表，也不会自动出现在导航或页面分发中。`docs/module-system-status.md` 中“SettingsDialog 导航 Repeater”的描述已经过时。

### P0：服务和独立应用不受注册表管理

`apps/omd-bar/shell.qml` 直接引用或初始化：

- VoiceInput
- InputMethod
- Notifications
- Hyprsunset
- Lock
- SessionAutoRestore
- OnScreenDisplay

注册表不读取 `services` 和 `apps`，因此无法做到：

- 禁用插件后不创建服务对象。
- 禁用插件后不注册 IPC。
- 按需冷启动独立应用。
- 卸载插件时检查仍被核心引用的服务。

### P0：Popup 注册不是通用挂载点

`BarStatusPopup.qml` 的主 `Loader` 仍按固定字符串分支：`wifi`、`bluetooth`、`audio`、`display`、`battery`、`notifications`、`voice`、`inputMethod`、`keyboard`、`session`、`xkb`、`tools`。

动态 `ModuleLoader.popupSections` 的 Repeater 位于 `audioContent` 内部。这使 `popupSections` 实际更像“向 Audio Popup 插入 section”，而不是通用 Popup 注册。

当前 MPRIS 就依赖：

- 核心 `AudioButton`
- 核心 `MprisController` / `TrackArt`
- 清单中的魔法字符串 `type: "audio"`
- 核心中的 `modulesEnabled` 回退分支

这是紧耦合的混合实现，插件不能独立拥有媒体入口和生命周期。

### P1：应用启动器、锁屏、媒体没有统一注册

#### 应用启动器

应用启动器入口由 `ModuleLoader.leftBarModules` 硬编码；对应独立进程也不在任何模块运行时注册中。它可以继续是必装组件，但仍应通过“内置模块清单”注册，而不是在加载器中写文件路径。

#### 锁屏

锁屏文件已移到外部目录，但：

- 启动脚本按目录名 `lock` 特判并创建 symlink。
- `apps/omd-bar/shell.qml` 直接 `import qs.modules.lock` 并实例化 `Lock {}`。
- 电池 Popup 中的 LOCK 按钮仍由核心写死。
- `lock/module.json` 没有声明任何入口、服务或动作。

锁屏是安全关键能力，不应被普通可选插件随意关闭。但正确做法是“required provider + fallback”，而不是“一部分外置、一部分硬编码”。如果 provider 缺失，应该 fail closed 或回退到受支持的锁屏程序。

#### 媒体播放器

MPRIS Popup 已部分外置，但按钮、服务和后备实现仍在核心。当前外置范围不足以称为独立插件。

### P1：注册表不够可靠

当前注册表存在以下运行时风险：

- 固定写入 `/tmp/sumika-module-registry.json`，不是用户/会话隔离路径。
- 非原子写入，读取时可能碰到半个 JSON。
- `modules.enabled=false` 时不删除旧注册表。
- ModuleLoader 只在进程启动时读取一次，没有 reload/watch。
- 清单解析失败时可能静默保留旧 `registry`，错误模块被悄悄丢弃。
- 没有 `schemaVersion`、ID 唯一性、依赖、组件存在性和类型验证。
- 目录名与清单 `id` 没有强制一致，但 symlink 和管理命令使用目录名。

### P1：禁用模块仍会暴露代码与命令

启动脚本在检查总开关之前，就把所有插件加入 `QML_IMPORT_PATH` 和 `PATH`。所以“禁用”仅影响部分 Loader 结果，不代表插件命令、QML 或服务不可用。

### P1：安装路径和部署不完整

插件目录默认写死为 `~/development/sumika-modules`。`Init.sh` 没有负责获取或安装该目录。

结果是：只克隆 OMD 并运行 `Init.sh`，不能保证获得当前机器上的完整功能，尤其是已经被外置并被核心直接 import 的锁屏。该问题也与仓库“克隆后可完整部署”的目标冲突。

### P2：文档与实现漂移

`docs/module-system-status.md` 至少有这些失真项：

- 声称 SettingsDialog 消费动态设置页，实际没有。
- 表格写“右侧按钮受 per-module 控制”，实际只有总开关。
- 描述 MPRIS 已提取，但核心仍保留服务和媒体实现。
- 一边把锁屏定义为不可拆安全核心，一边建议让它服从普通模块总开关；安全边界没有定稿。

---

## 5. 建议的目标模型

### 5.1 区分三种状态

模块管理必须区分：

1. **installed**：模块文件存在并通过清单校验。
2. **enabled**：用户允许该模块参与本次桌面会话。
3. **loaded/running**：对应 UI、服务或进程已经加载。

建议配置：

```json
{
  "modules": {
    "enabled": true,
    "active": [
      "app-launcher",
      "lock",
      "mpris",
      "clipboard",
      "session"
    ],
    "order": {
      "bar.right": ["input-method", "audio", "display", "session"]
    }
  }
}
```

`required` 模块不允许普通 UI 关闭，或必须先选择替代 provider。

### 5.2 内置功能也走同一注册表

“核心功能”不等于“硬编码”。建议在 OMD 内增加内置清单目录，例如：

```text
quickshell/registry/builtin/
  shell.json
  app-launcher.json
  audio.json
  network.json
  notifications.json
```

启动时把内置清单和外部 `module.json` 合并成同一注册表。这样：

- App Launcher 可以是 required/builtin 模块。
- Lock 可以是 required provider。
- Audio 可以是 builtin，MPRIS 作为对 Audio Popup 的可选 contribution。
- Bar 不需要知道具体插件 ID，只渲染注册后的 placement。

### 5.3 注册能力应覆盖完整桌面入口

建议清单至少表达：

```json
{
  "schemaVersion": 1,
  "id": "mpris",
  "kind": "optional",
  "dependencies": ["audio"],
  "contributions": {
    "barItems": [],
    "popupRoutes": [],
    "popupSections": [],
    "settingsPages": [],
    "actions": [],
    "processes": [],
    "serviceProviders": [],
    "ipcHandlers": []
  }
}
```

关键概念：

- `barItems`：按钮组件、left/right slot、order、popup/action。
- `popupRoutes`：完整 Popup 页面 provider。
- `popupSections`：向某个明确 extension point 追加区块，如 `audio.afterHeader`。
- `actions`：锁屏、注销、重启、打开设置等命令，可声明放置到 `battery.session`、`overview.menu`、`launcher.menu`。
- `processes`：独立 Quickshell app 或守护进程，声明 `always`、`on-demand`、`event-driven` 生命周期。
- `serviceProviders`：服务 provider 及其接口，避免核心直接 import 插件具体类。
- `ipcHandlers`：插件拥有的 IPC 名称，启用时注册，禁用时不存在。

### 5.4 核心只保留挂载点

核心代码应只认识挂载点，不认识具体插件名：

```text
bar.left
bar.right
popup.route.<type>
popup.audio.afterHeader
settings.navigation
battery.session.actions
overview.command.actions
launcher.context.actions
```

例如 LOCK 按钮不应该在 Battery Popup 中手写。Lock provider 注册一个 action，并声明 placement 为 `battery.session.actions`。Battery Popup 只渲染动作列表。

### 5.5 锁屏的安全策略

建议把锁屏定义为：

- `kind: required-provider`
- capability: `session-lock`
- 默认 provider: `sumika-lock`
- fallback: `swaylock` 或明确的错误阻断

按钮和自动锁屏逻辑都调用 `session-lock` 接口，而不是 import `Lock.qml`。这样锁屏仍然可以模块化注册，但不会因为普通插件开关而被无意移除。

---

## 6. 推荐迁移顺序

### Phase 1：先修注册表，不移动更多文件

1. 定义并校验 `schemaVersion: 1`。
2. 把注册表移动到 `$XDG_RUNTIME_DIR/sumika-shell/modules.json`。
3. 使用临时文件 + `mv` 原子写入。
4. 注册表包含 installed/enabled/required/errors 和全部 contributions。
5. 启动失败时明确报告坏清单，不静默跳过。
6. 恢复逐插件配置，修复 ModulesPage 不应切换总开关的问题。

### Phase 2：统一 Bar 注册

1. 给现有静态按钮补内置或外部清单。
2. BarContent 只保留 left/right 两个 Repeater。
3. AppLauncher、ActiveWindow、Audio、WiFi、Clock 也通过 builtin 清单进入同一排序系统。
4. 外部 clipboard/session/display/input-method/systray 按钮由各自插件注册。

### Phase 3：统一 Popup 与 Action

1. 把固定 `activeType` 条件链改成 route registry。
2. 把 section 注册放到通用 extension-point host，而不是 Audio 内部的单个 Repeater。
3. LOCK、logout、restart、media controls 等通过 action/contribution 注册。

### Phase 4：接通 Settings

1. 合并 builtin pages 与外部 `settingsPages`。
2. 页面别名由清单声明，不再集中写 `normalizePage()`。
3. 页面组件由注册表查找，不再集中写 `pageComponent()` 条件分支。

### Phase 5：服务和进程生命周期

1. 将服务区分为 core service、optional provider、standalone process。
2. 只有启用插件才把它加入 import/path 和启动计划。
3. 剪贴板、设置、截图等继续使用冷启动；manifest 负责注册命令和入口。
4. 逐个消除核心与插件目录中的重复源码。

### Phase 6：最后做物理拆分和部署

1. 每项能力确定唯一 owner 后再删除核心副本。
2. `Init.sh` 安装固定版本的插件集合，或把插件作为 submodule/package 管理。
3. `omd-doctor` 校验 required provider、依赖、清单、组件和命令。

---

## 7. 验收标准

模块系统完成后，应满足：

1. 新增一个普通 Bar 插件不需要修改 OMD QML 源码。
2. 安装、启用、禁用、卸载是四个可验证的独立动作。
3. 禁用 MPRIS 后，媒体 UI、服务和相关 IPC 都不加载，但 Audio 仍正常。
4. 禁用 Clipboard 后，不显示按钮、不启动存储 watcher、不注册快捷键。
5. App Launcher、Lock、Media 的入口都可在注册表中追踪到 owner。
6. Lock provider 缺失时有安全 fallback，不能静默变成无锁状态。
7. Settings 页面仅靠 manifest 即可加入和移除。
8. Bar 顺序只由统一 placement/order 决定，没有“静态按钮区 + 动态尾部”两套排序。
9. 清单损坏时启动日志和 `omd-doctor` 都给出明确错误。
10. 只克隆并运行文档化安装流程，可以复现完整 required 模块集合。

---

## 8. 建议优先处理的具体项

按收益与风险排序：

1. 修复 ModulesPage 的伪逐插件开关。
2. 让 SettingsDialog 真正消费 `settingsPages`，或在接入前暂时删除错误文档和无效 UI。
3. 将 AppLauncher、Clipboard、Session、Display、InputMethod、SysTray 的 Bar 入口转成清单注册。
4. 把动态 Popup Repeater 从 Audio 内容中移到通用路由/挂载点。
5. 为 Lock 定义 required-provider 契约，再移除启动脚本中的 `case lock` 特判。
6. 明确 MPRIS 的唯一 owner，移除核心与插件的双实现。
7. 处理剪贴板重复源码。
8. 最后再接服务懒加载和独立进程生命周期。

当前最重要的原则是：**插件是否存在、是否启用、提供哪些入口、启动哪些服务，必须能从一个注册表完整回答。核心 UI 不应再通过文件名、插件 ID 或 popup 字符串猜测这些信息。**

---

## 9. 修改后复审（2026-07-21）

### 9.1 本轮审查范围

本节针对上一轮审查后的未提交修改进行复审，重点检查：

- `quickshell/registry/builtin/bar.json`
- `quickshell/scripts/quickshell`
- `quickshell/services/ModuleLoader.qml`
- `quickshell/modules/bar/BarContent.qml`
- `quickshell/modules/bar/BarStatusPopup.qml`
- `quickshell/modules/settings/SettingsDialog.qml`
- `quickshell/modules/settings/pages/ModulesPage.qml`
- `bin/omd-modules`
- `docs/module-system-status.md`

静态重建注册表的结果为：

| 项目 | 数量 |
|---|---:|
| 模块 | 17（16 个外部模块 + 1 个 builtin 清单） |
| Bar 按钮 | 12 |
| Popup section | 10 |
| Settings page | 7 |

12 个 Bar 组件路径均存在。因此，当前“右侧时间、Wi-Fi、音量、电源全部消失”并不是 `bar.json` 少写了这四项，也不是组件文件被删除，而是下面的注册表生命周期问题。

### 9.2 严重回归：右侧 Bar 已无任何静态 fallback

`BarContent.qml` 已删除原来的直接实例：

- `AudioButton`
- `WifiButton`
- `ClockWidget`
- `SidebarIndicators`（电池/电源入口位于这里）
- 以及 SysTray、InputMethod、Clipboard、Session、Display、Tools

右侧现在唯一的数据源是：

```qml
Repeater {
    model: ModuleLoader.rightBarButtons
}
```

这意味着只要注册表不存在、尚未生成、读取失败、路径不一致或 JSON 暂时无效，整个右侧区域就会变成空数组。用户观察到的时间、Wi-Fi、音量和电源同时消失，正好符合这一失败模式。

本次审查时，预期运行时文件：

```text
$XDG_RUNTIME_DIR/sumika-shell/modules.json
/run/user/1000/sumika-shell/modules.json
```

并不存在。虽然在 `/tmp` 中使用同一套 `jq` 逻辑可以成功重建 12 个按钮，但这只能证明 manifest 内容基本正确，不能证明启动时注册表一定存在并已被 `ModuleLoader` 读取。

#### 建议修复

1. builtin 注册表必须无条件生成，不能依赖外部插件目录存在。
2. `modules.enabled: false` 时不能删除整份注册表；应保留 builtin contribution，再由 Loader 过滤可选模块。
3. `ModuleLoader` 在注册表缺失或解析失败时必须提供 builtin fallback，至少保证 Audio、Wi-Fi、Clock、Power 和桌面基本入口存在。
4. 启动日志应明确输出最终注册表路径、按钮数量和错误，不能把空右栏当作正常状态。
5. `omd-doctor` 应验证注册表存在、schema 正确、所有 component 可读，并检查核心按钮数量。

### 9.3 严重逻辑错误：`alwaysShow` 在总开关关闭时实际无效

新文档声称 `modules.enabled: false` 时，`alwaysShow: true` 的 AppLauncher、ActiveWindow、Audio、Wi-Fi、Clock、SidebarIndicators 仍会显示。但启动脚本当前会在总开关关闭时执行：

```sh
rm -f "$registry_dir/modules.json"
```

`alwaysShow` 信息本身只存在于被删除的注册表中。`ModuleLoader._registry` 随后为空，`_filterBarButtons()` 没有任何条目可筛选，所以所谓 alwaysShow 按钮也不会出现。

因此，`docs/module-system-status.md` 中关于总开关关闭后仍保留核心按钮的描述与代码不符。

### 9.4 高风险：builtin 生成被错误地包在外部插件目录判断内

整个注册表生成逻辑位于：

```sh
if [ -d "$SUMIKA_MODULES_HOME" ]; then
    # external scan
    # builtin merge
fi
```

如果用户只克隆 OMD、插件目录尚未安装、插件目录改名或挂载失败，builtin 清单也不会生成。此时不只是插件缺失，连核心 Bar 都会消失。

builtin 清单属于 OMD 核心，必须在外部插件扫描之外独立生成。外部目录缺失只应让外部 contributions 为空，不应破坏桌面基本 UI。

### 9.5 高风险：注册表失败被静默降级为空或旧状态

启动脚本的 `jq` 合并使用了错误输出捕获和回退：

```sh
registry=$(jq ... 2>&1 || echo "$registry")
```

这会带来两个问题：

1. manifest 解析失败时没有模块级错误报告，启动仍继续。
2. 错误文本可能与回退 JSON 一同进入命令替换结果，最终写出无效注册表。

此外，如果系统没有 `jq`，外部和 builtin 合并都会被跳过，但脚本仍会写出一份合法却完全为空的注册表，表现仍是整个 Bar 消失。

建议对每份 manifest 独立校验；任何 builtin 清单错误应让 Bar 启动明确失败或进入 builtin fallback，不能静默生成空数组。

### 9.6 配置契约分叉：`exclude` 与 `disabled`

当前实现统一读写的是：

```text
modules.disabled
```

涉及：

- `Config.qml`
- `ModulesPage.qml`
- `bin/omd-modules`

但 `docs/module-system-status.md` 的架构图、章节标题、配置表和命令示例多处写成：

```text
modules.exclude
```

同一文档内部甚至同时出现 `property list disabled` 和 `modules.exclude`。后续实现者按文档配置 `exclude` 时不会产生任何效果。

必须选择一个最终字段并一次性统一代码、用户配置、CLI 和文档。迁移期如需兼容旧字段，应明确优先级和迁移逻辑，不能让两个名称长期并存。

### 9.7 Settings 动态页面接入仍存在重复和不可达页面

`SettingsDialog.pages` 现在直接把外部 `settingsPages` 附加到固定 `primaryPages` 后面，但没有按 key 去重：

- `power` 同时存在固定页面和 `battery-power` 模块页面。
- `keyremap` 同时存在固定页面和 `keyboard-remap` 模块页面。

页面查找使用 `find()`，重复 key 会优先命中固定页面；模块页面虽然进入导航数组，实际仍可能无法被选中。

另外，`normalizePage()` 在查询模块注册表之前就把以下模块 ID 重定向到了固定页面：

- `windows-vm` → `overview`
- `voice` / `voice-input` / `speech` → `overview`
- `keyboard` / `keymap` / `remap` → `keyremap`

因此这些动态页面已经注册，却仍被旧的硬编码路由截获。当前实现还没有达到“manifest 注册后即可访问”的目标。

建议先定义覆盖规则：builtin 与 plugin key 冲突时是替换、扩展还是拒绝；然后在单一索引中完成去重、alias 解析和组件选择。

### 9.8 Popup contribution 类型仍未区分，可能重复渲染完整面板

`BarStatusPopup.qml` 把所有 `popupSections` 放到通用容器中，这是比“只挂在 audio 内部”更合理的方向。但当前逻辑仍会同时加载：

1. 核心 `contentLoader` 对应的完整内容；
2. 所有 `type` 相同的外部 Popup 组件。

现有模块中的 Battery、Display、Input Method、Keyboard、Session、Voice 等组件名称和职责更接近完整 Popup，而不仅是附加 section。若核心内容尚未移除，同类型会出现重复 UI、重复控制或异常高度。

注册契约需要区分：

- `popupRoutes`：替换某个 type 的完整内容，最多一个 active provider；
- `popupSections`：挂到明确 extension point 的附加区块，可以有多个。

不能只通过相同的 `type` 字符串把两类组件都追加在主体之后。

### 9.9 `alwaysShow` 与模块 ID 的语义不清晰

builtin manifest 中每项手写了 `moduleId: "builtin"`，但生成器随后统一覆盖成清单 ID `builtin-bar`。最终注册表里的真实 moduleId 是 `builtin-bar`。

这不会直接导致本次右栏消失，因为 alwaysShow 项绕过 `isEnabled()`；但它说明 manifest 中的 `moduleId` 字段是无效、误导性的。对非 alwaysShow 项，禁用粒度也变成“一次禁用整个 builtin-bar”，而不是分别禁用 systray、input-method、clipboard 等功能。

如果目标是逐模块启停，按钮应归属各自真正的 owner；如果它们确实属于单一 builtin provider，就应删除 manifest 内无效的 `moduleId`，并明确不能逐项禁用。

### 9.10 当前修复优先级（交给后续实现者）

#### P0：先恢复桌面基本入口

1. 让 builtin 清单无条件可用，独立于 `SUMIKA_MODULES_HOME` 和 master switch。
2. 注册表不存在或损坏时加载 builtin fallback。
3. 验证右侧至少恢复 Audio、Wi-Fi、Clock、SidebarIndicators。
4. 增加注册表生成与 Loader 读取的可观测错误。

#### P1：修正配置和路由契约

1. 统一 `modules.disabled` / `modules.exclude`。
2. 修复 Settings page key 去重、alias 顺序和不可达模块页面。
3. 区分 popup route 与 popup section。

#### P2：再继续插件化

1. 将可选 Bar 按钮归属到各自模块，而不是统一归属 `builtin-bar`。
2. 接入 `services`、`apps`、`binScripts` 生命周期。
3. 实现热重载、错误隔离和按模块诊断。

### 9.11 本轮验收清单

后续智能体修复后至少应验证以下场景：

1. 外部插件目录存在、所有模块启用：左右 Bar 完整显示。
2. 外部插件目录不存在：核心 Bar 仍显示，日志只报告外部模块缺失。
3. `modules.enabled: false`：文档声明的 alwaysShow 核心项确实仍显示。
4. 注册表 JSON 人为损坏：核心 Bar fallback 生效，并有明确日志。
5. 缺少 `jq`：不得静默启动成空 Bar。
6. 分别禁用 mpris、clipboard、session：只影响目标模块。
7. Settings 中每个 key 只出现一次，`voice`、`windows-vm`、`keyremap` 能进入预期 provider。
8. 各 Popup type 不出现核心内容与完整插件 Popup 重复叠加。
9. `omd-modules list`、ModulesPage 和实际 Loader 对同一模块给出一致状态。

### 9.12 修复：BarStatusPopup.qml 因 audioHeader 缺失闭大括号导致 QML 解析失败

**背景：** 在将 popupSections Repeater 从 `audioContent` 内部移至上层的重构中（见 9.2），
`audioHeader` Item 的闭合大括号被误删。该大括号与原 Repeater 位于同一缩进层，删除 Repeater 区块时一并被移除。

**症状：** `BarStatusPopup.qml` 第 2834 行 `Expected token '}'`，QML 解析失败，bar 进程崩溃。
`PopupSliderRow` 及之后的输入输出设备列表被错误嵌套在 `audioHeader` 内部，导致连锁未闭合块直至 EOF。

**修复：** 在 Bottom Divider `Rectangle` 后插回 8 空格缩进的 `}`，
使 `audioHeader` 在其子元素全部结束后正确关闭，后续内容恢复为 `audioColumn` 的平级子元素。

**验证：** `omd-restart` 后 bar 正常启动，日志无 QML parse error。

**涉及文件：** `quickshell/modules/bar/BarStatusPopup.qml`（+1 行）。

### 9.13 对 `bca44d3..3ee4f42` 的修复后复审

本节复审 2026-07-21 本轮六个提交的实际 diff，而不是只依据“Bar 已能启动”这一运行现象：

- `e20cf61`：无条件生成 builtin registry，并改为 runtime directory + atomic write。
- `6aa9d74`：增加 per-module `isEnabled()`、左右 Bar 注册列表和 registry 日志。
- `c104c25`：Bar 全面改为 registry 驱动，并把 popup section Repeater 移到通用容器。
- `4f97270`：Settings 动态页面合并、模块开关修复。
- `75c4493`：CLI/doctor 路径及 `modules.disabled` 对齐。
- `3ee4f42`：状态文档、审查文档及 9.12 括号修复记录。

#### 已确认修复的部分

1. **本轮右侧 Bar 消失的直接原因已处理。** builtin manifest 的生成不再依赖
   `SUMIKA_MODULES_HOME` 是否存在，也不再因 `modules.enabled: false` 删除整份 registry。
   当前运行时 registry 位于 `$XDG_RUNTIME_DIR/sumika-shell/modules.json`，包含 17 个模块、
   12 个 Bar 按钮、10 个 popup section 和 7 个 settings page；所有 component 路径均存在。
2. **核心 Bar 的降级语义基本恢复。** App Launcher、Active Window、Audio、Wi-Fi、Clock、
   Sidebar Indicators 均带 `alwaysShow: true`，master switch 关闭时仍可从已生成 registry 中加载。
3. **registry 写入比之前可靠。** 生成路径从全局 `/tmp` 改到用户 runtime directory，并使用
   临时文件 + `mv` 原子替换，避免 Reader 读到半份 JSON。
4. **配置字段在代码中已统一为 `modules.disabled`。** `Config.qml`、ModulesPage、
   `omd-modules` 使用同一字段；逐模块按钮不再误切换 master switch。
5. **9.12 描述的 QML 结构修复成立。** `audioHeader` 已在 divider 后闭合，后续 slider/device
   内容重新成为 `audioColumn` 的平级项。`quickshell/scripts/quickshell` 和 `bin/omd-modules`
   均通过 `bash -n`。

结论：**时间、Wi-Fi、音量等右侧核心项同时消失的故障可以判定为已修复，但模块注册系统尚不能判定为完成。**

#### P0：ModuleLoader 本身仍没有 builtin fallback

启动脚本现在能在缺少 `jq` 时写一份最小 registry，但 `ModuleLoader.qml` 在以下情况仍只保留
`_emptyRegistry()`：

- 用户直接执行 `qs -p ...`，绕过 `quickshell/scripts/quickshell`；
- runtime registry 被删除；
- registry JSON 损坏；
- `SUMIKA_MODULE_REGISTRY` 指向不存在的文件。

Reader 当前只打印 warning，不会加载内置资源；`leftBarButtons` 与 `rightBarButtons` 因此仍会同时为空。
这与 9.2、9.10 中“registry 缺失或损坏时核心 Bar fallback 生效”的验收条件不符。

**建议：** 在 `ModuleLoader` 内维护一份真正可执行的 builtin fallback，或直接读取 repo 内的
`registry/builtin/bar.json` 作为第二数据源。Shell 生成器的 fallback 只能算第一层保护，不能代替
UI Loader 的失败保护。

#### P1：Bar 按钮的 owner 仍然错误，逐模块禁用不会控制对应图标

生成器会用 manifest ID 覆盖每个 Bar 条目的 `moduleId`。因此当前 12 个 builtin Bar 按钮的真实
owner 全部是 `builtin-bar`，而不是 `systray`、`input-method`、`clipboard`、`session`、`display`
等外部模块。

实际结果：

- 禁用 `display`：Display popup/settings contribution 会消失，但顶部 Display 按钮仍在。
- 禁用 `clipboard`：剪贴板模块会停用，但顶部 Clipboard 按钮仍在。
- 禁用 `builtin-bar`：会一次性隐藏 SysTray、Input Method、Clipboard、Session、Display、Tools。

这不符合“插件自己注册并拥有入口”的目标，也会留下点击后缺少 provider 的空入口。

**建议：** builtin manifest 只保留真正核心的按钮。可选按钮应由对应插件的 `module.json`
注册；如果必须保留 builtin 壳，则清单需要单独的 `ownerModuleId`/`requiresModule` 契约，生成器
不能无条件覆盖它。

#### P1：`popupSections` 仍同时承担 route 与 extension 两种职责

Repeater 从 `audioContent` 移到通用容器是正确方向，但当前会先加载固定 `contentLoader`，再追加
同 type 的外部 section。于是 `battery`、`display`、`inputMethod`、`keyboard`、`session`、`voice`
同时存在内置内容与外部内容；而 `file-backup`、`ocr`、`windows-vm` 又依赖空的内置页面，事实上
把 section 当作完整 route 使用。

这使同一 capability 在不同模块中语义不同，也容易出现重复 UI、重复 service 调用和高度计算问题。

**建议：** 落实 9.8 的契约拆分：`popupRoutes` 每个 type 只允许一个完整页面 provider；
`popupSections` 必须指定 extension point，例如 `audio.afterHeader`，只能追加局部内容。

#### P1：Settings 页面冲突只是被隐藏，未真正解决

`pages` 对相同 key 做了去重，但 `pageComponent()` 仍优先返回固定组件。当前 registry 中：

- `battery-power` 注册 `power`，与 primary `power` 冲突，外部页面不可达；
- `keyboard-remap` 注册 `keyremap`，与 primary `keyremap` 冲突，外部页面不可达；
- `display` 额外注册 `display-settings`，会与 primary `display` 同时出现在导航中，而常规
  `display` 入口仍打开内置页面。

因此这里不是“动态页面已接管”，而是“冲突页面不显示或生成第二入口”。此外 `windows`、
`virtualization`、`vm` 的硬编码 redirect 位于模块 alias 查询之前，未来插件无法声明这些 alias。

**建议：** 建立唯一 route index，并明确冲突策略（replace / extend / reject）。所有 normalize、
alias、导航项和 component 选择都从该 index 读取，不能继续由硬编码 `if` 与动态表并行决定。

#### P2：文档与实现仍有残留不一致

1. `docs/module-system-status.md` 主体已经使用 `modules.disabled`，但场景表和 MPRIS 示例仍写
   `exclude` / `exclude:["mpris"]`，会继续误导后续实现者。
2. 状态文档描述的 registry 合并顺序与代码不完全一致；代码是先 builtin、后 external。
3. 9.12 写“文件长度 2835 行”，当前实际为 2834 行。括号修复本身正确，但该验证数字应修正，
   不应把行数作为结构正确性的依据。
4. Modules 页面仍显示“Changes apply after restart”，但 `Config.options.modules.disabled` 已参与
   QML 响应式过滤；需要明确哪些变更即时生效、哪些服务卸载必须重启。

#### 本轮建议验收状态

| 项目 | 状态 |
|---|---|
| 右侧核心 Bar 恢复 | 通过 |
| builtin 无条件生成 | 通过 |
| master switch 保留 alwaysShow | 通过（前提：registry 已生成且有效） |
| registry 缺失/损坏时 UI fallback | 未通过 |
| 可选按钮归属对应插件 | 未通过 |
| Popup route/section 契约 | 未通过 |
| Settings 动态路由与冲突处理 | 未通过 |
| `disabled` 配置字段代码统一 | 通过 |
| 文档字段完全统一 | 未通过 |

下一轮应先完成 Loader 内 fallback 和按钮 owner 修复，再处理 Popup 与 Settings 契约。否则继续增加
插件只会扩大当前“注册成功但入口/页面并不真正受该插件控制”的问题。

### 9.14 修复：ModuleLoader 内 fallback + 按钮 owner + Settings 路由优先级

本节对应 9.13 建议的"下一轮应先完成 Loader 内 fallback 和按钮 owner 修复"。

**1. ModuleLoader 内置 fallback（P0）**

新增 `_builtinFallback` 硬编码列表，包含 6 个 alwaysShow 核心按钮
（AppLauncher、ActiveWindow、Audio、Wifi、Clock、SidebarIndicators）。
当 registry 文件缺失、损坏、或 `barButtons` 为空时，`_filterBarButtons()` 自动降级使用该列表，
保证 bar 永远不会完全空白。

涉及文件：`quickshell/services/ModuleLoader.qml`（+18 行）。


**2. 按钮 owner 修复（P1）**

`quickshell/registry/builtin/bar.json` 中可选按钮的 `moduleId` 改为其对应外部模块 ID：

| 按钮 | 原 moduleId | 现 moduleId |
|---|---|---|
| SysTray | builtin | systray |
| Input Method | builtin | input-method |
| Clipboard | builtin | clipboard |
| Session | builtin | session |
| Display | builtin | display |
| Tools | builtin | builtin（无可选模块） |

现在禁用 `clipboard`、`session`、`display` 等模块会同时隐藏其对应 Bar 按钮。
同时修复启动脚本的 jq merge 表达式：原 `map(. + {moduleId: $mod[0].id})` 无条件覆盖了每项已有的
`moduleId`，改为 `| .moduleId = (.moduleId // $mod[0].id)` 保留显式声明的 moduleId。

**3. SettingsDialog 路由优先级（P1）**

`pageComponent()` 顺序调整为：
1. 纯核心页面（network、bluetooth、appearance、system）→ 固定组件
2. 模块注册页面 → 动态组件（如 battery-power 的 `power`、keyboard-remap 的 `keyremap`）
3. 核心回退（display、keyremap、power）→ 仅当无模块注册时使用

现在 `battery-power` 注册的 `power` 页面、`keyboard-remap` 注册的 `keyremap` 页面可以正常到达。

**4. 文档修复（P2）**

- `docs/module-system-status.md`：全部 `exclude` 改为 `disabled`；修复注册表合并顺序描述。
- `docs/module-registration-audit.md`：9.12 行数错误修正；增加本节。

#### 本轮后验收状态

| 项目 | 上轮状态 | 当前状态 |
|---|---|---|
| 右侧核心 Bar 恢复 | 通过 | 通过 |
| builtin 无条件生成 | 通过 | 通过 |
| master switch 保留 alwaysShow | 通过 | 通过 |
| registry 缺失/损坏时 UI fallback | 未通过 | **已修复** |
| 可选按钮归属对应插件 | 未通过 | **已修复** |
| Popup route/section 契约 | 未通过 | 未通过 |
| Settings 动态路由与冲突处理 | 未通过 | **部分修复**（power/keyremap 可达，display-settings 重复入口未解决） |
| `disabled` 配置字段代码统一 | 通过 | 通过 |
| 文档字段完全统一 | 未通过 | **已修复** |

#### 待办

1. **Popup route/section 契约** — 区分完整 Popup 接管（popupRoutes）与局部 section（popupSections）。
2. **display-settings 重复入口** — display 模块注册 `display-settings` 会产生第二个导航项。
3. **注册表热重载** — ModuleLoader 只启动时读取一次，运行时修改 `modules.disabled` 需重启。
4. **模块按钮组件路径** — 可选按钮的 component 仍指向核心路径，而非外部模块的独立实现。
