# Sumika Core 模块拆分后审计报告

> 状态：待整改  
> 审计基线：`module-split` 分支，2026-07-24  
> 历史架构参考：
> [Sumika Core / Plugin 目标架构与迁移计划](sumika-core-plugin-migration-plan.md)  
> 执行基准：
> [插件化迁移执行清单](sumika-plugin-migration-execution-checklist.md)

> **边界修正**：上述历史文档中“Core 不提供功能、TopBar/Overview 是空宿主”
> 的目标已经被最新产品决定取代。当前权威边界是“Core 提供可独立使用的最小
> 桌面；插件提供额外扩展”。执行 agent 不得按旧目标删除当前固定加载的基本
> 桌面功能。

## 1. 审计目标

本报告检查“删除外置模块后”的当前实现是否已经满足以下目标：

1. Core 本身构成可独立使用的最小桌面，而不是空宿主。
2. 最小桌面包含当前固定加载的 TopBar、Overview、Workspace 状态、
   Applications/Launcher、Wi-Fi、Audio、Display、Power 等基本能力。
3. `modules.enabled=false` 只关闭额外扩展，不能拆掉最小桌面。
4. Core 内部基本功能仍应有清晰的组件、Action 和 Service 所有权，避免重复注册。
5. Core 之外的可选模块必须可以禁用、卸载和失败，且不会拖垮 Shell。
6. 删除外置模块仓库后，运行时、安装器、诊断器和命令入口中不再存在悬空引用。

本审计以用户确认的上述产品边界为准。它修正了旧架构文档中“Core
不提供功能、TopBar/Overview 为空宿主”的定义：Sumika Core 的职责是保证一套
完整且可用的最小桌面；插件系统用于扩展这套桌面，而不是组装其基本生存能力。

本轮只审计并记录问题，没有修改实现。

## 2. 审计结论

当前不能判定“模块拆分已经完成”。

已完成的部分：

- 已存在 `ModuleLoader`、`ActionManager`、`ServiceManager`、
  `ApplicationManager` 和 manifest schema 等 Runtime 骨架。
- 10 个功能目录已有 `module.json`，且都能通过
  `bin/omd-module-validate`。
- Bar Widget、Popup Section、Settings Page 等贡献已部分转为清单生成。
- 当前仓库没有发现悬空 symlink。

尚未完成的核心部分：

- 当前固定加载最小桌面的行为正确，不应把 Overview、Workspace、Wi-Fi、
  Audio、Display、Power 或 Applications/Launcher 从 Core 中移除。
- Core 内部仍存在重复事实源、跨功能所有权和可选功能残留，需要收敛，但这不
  等于要删除最小桌面功能。
- 删除外置模块后，脚本、QML Service、命令入口和文档仍大量依赖
  `$SUMIKA_MODULES_HOME`。
- 设置、截图、语音、输入法、键盘映射等入口存在确定的悬空路径。
- `Init.sh` 当前存在语法错误，干净安装无法执行。
- `modules.enabled=false` 后最小桌面继续加载是预期行为；字段文档和命名需要
  明确它控制的是额外模块。
- `trustedInProcess` 只应约束未来的非 Core 扩展；当前内置最小桌面不应因此
  被阻止加载。

因此，当前状态更准确的描述是：

> 最小桌面已经回嵌并能由 Registry 加载，但内部所有权收敛、可选扩展隔离和
> 外置模块退场尚未完成。

## 3. 当前实际结构

### 3.1 仓库内功能模块

当前 `quickshell/modules/` 包含：

```text
audio
bar
clock
common
display
launcher
notification-popup
overview
polkit
power-indicator
systray
wifi
workspaces
```

其中以下 10 个目录包含 `module.json`：

```text
audio
clock
display
launcher
notification-popup
overview
power-indicator
systray
wifi
workspaces
```

这些目录中既有最小桌面的 Core 功能组件，也有可能属于可选扩展的残留。
`AGENTS.md` 中“`quickshell/modules/` 只有 bar、common、polkit 三个 Core
shared QML module”的描述已经过期，不能再作为删除当前基本功能的依据。

### 3.2 已删除的外置目录

`~/development/sumika-modules/` 当前不存在，但以下机制仍假设它存在：

- 路径 API；
- 启动阶段模块扫描和 staging；
- 模块管理 CLI；
- 设置、截图、OCR、语音、键盘映射、输入法等命令入口；
- 休眠和唤醒脚本；
- doctor 检查；
- 安装完成提示；
- 若干 QML Service。

### 3.3 建议明确最终源码策略

既然外置模块仓库已经删除，建议采用“单仓库、最小桌面 Core + 可选扩展”
的分层所有权：

```text
quickshell/core/       # Runtime、API 和最小桌面编排
quickshell/modules/    # Core 基本功能的内部组件
modules/optional/      # 可选官方/第三方扩展
apps/                  # 独立进程应用入口
```

也可以使用其他目录名，但必须满足：

- 删除全部可选模块后，Core 仍能提供当前最小桌面；
- Core 基本功能与可选扩展在源码和生命周期上可区分；
- 可选扩展不能绕过模块生命周期和隔离规则；
- 最小桌面内部仍使用统一 Registry/Action/Service 机制，不能同时保留两套注册。

## 4. 阻塞问题

### P0-1 `Init.sh` 存在语法错误

证据：

- `Init.sh:1388-1405` 的 `print_summary()` 中，`elif` 分支后缺少 `fi`。
- `bash -n Init.sh` 报错：

```text
Init.sh: line 1405: syntax error near unexpected token `}'
```

同一位置还在提示用户 clone 已删除的 `sumika-modules` 仓库。

影响：

- 新机器无法按 Quick Start 完成安装。
- 不能把当前仓库视为可复现部署。

整改：

1. 补全条件语句。
2. 删除外置模块 clone 提示。
3. 对 `Init.sh` 增加 CI 或本地 `bash -n` 门禁。

验收：

```sh
bash -n Init.sh
./Init.sh
./Init.sh
```

两次运行都必须成功，第二次必须幂等。

### P0-2 `omd-doctor` 自身不可用

证据：

- `bin/omd-doctor:5` source 已不存在的 `scripts/omd-path.sh`。
- 当前规范路径实现是 `lib/paths.sh`。
- source 失败后脚本继续运行，并可能在访问
  `SUMIKA_MODULES_HOME` 时以 unbound variable 退出。
- OCR、Voice 等检查仍直接检查已删除的外置模块目录。

影响：

- 项目规定的推送前验证命令不能提供可信结果。
- 迁移残留会被误报成用户依赖缺失。

整改：

1. 改用统一 Path API。
2. Doctor 只检查当前清单中已安装且启用的模块。
3. 模块专属诊断由模块贡献，Core Doctor 不硬编码 OCR、Voice 等功能名。
4. 缺少可选模块应是 `SKIP`，不是 Core `FAIL`。

验收：

```sh
bin/omd-doctor
```

必须完整执行，不发生 shell 异常；删除任意可选模块后仍能完成 Core 检查。

### P0-3 Settings 入口悬空

证据：

- `apps/omd-settings/shell.qml:6` 导入 `qs.modules.settings`。
- 当前不存在 `quickshell/modules/settings/`。
- `bin/omd-settings` 先寻找该目录，再回退到已删除的
  `$SUMIKA_MODULES_HOME/settings`。
- `ActionManager` 和 Display Popup 仍暴露 Settings Action。

影响：

- UI 显示可点击入口，但执行必然失败。
- 应用入口、模块所有权和实际文件位置不一致。

注意：

Settings 相关文件存在并发未提交修改的可能。整改 agent 必须先执行
`git status --short`，读取并保留最新工作区内容，禁止用旧版本覆盖。

整改选择：

1. 若 Settings 仍属于产品：将其恢复为仓库内独立应用，并提供唯一有效入口；
2. 若暂时删除 Settings：同时移除其 Action 和所有 UI 入口；
3. 不允许继续保留“Core 路径不存在时回退到已删除仓库”的假兼容逻辑。

验收：

```sh
bin/omd-settings
```

要么正常打开，要么该命令和全部入口被明确移除；不能保留半失效状态。

### P0-4 Screenshot 高级入口悬空

证据：

- `bin/omd-screenshot:19` 同样 source 已删除的 `scripts/omd-path.sh`。
- 它寻找 `modules/screenshot`，然后回退到
  `$SUMIKA_MODULES_HOME/screenshot`。
- 两个目录当前均不存在。

影响：

- 基于 `grim/slurp` 的部分直接路径可能仍可工作。
- Edit、OCR、Record 或 Quickshell Region Selector 等依赖模块文件的路径不可靠。

整改：

- 明确 Screenshot 是仓库内官方模块还是已删除功能。
- 将所有模式绑定到同一个 manifest 和实际存在的入口。
- 不允许 action 在模块缺失时仍注册为可用。

## 5. 外置模块删除残留

### P1-1 启动器仍扫描和 staging 外置模块

`quickshell/scripts/quickshell` 仍包含：

- 扫描 `$SUMIKA_MODULES_HOME/*/module.json`；
- 外置 QML staging；
- popup-components URI 重写；
- 外置 import path 注入；
- 本地模块与外置模块合并和优先级处理。

这些代码不再有有效数据源，并增加启动路径、错误面和维护成本。

整改：

- 只扫描一个权威模块根目录。
- Registry 生成必须纯 manifest 驱动。
- 删除 staging、路径猜测和 Core/External 路径优先级规则。
- 如果未来重新支持第三方目录，应通过明确的安装目录协议重新实现，
  不保留当前已失效的历史兼容层。

### P1-2 外置模块管理 CLI 已失去对象

以下工具仍围绕 `$SUMIKA_MODULES_HOME` 工作：

```text
bin/omd-modules
bin/omd-module-validate
bin/omd-settings-tui
bin/omd-powerprofiles-init
bin/omd-paste-at-cursor
bin/omd-restart
scripts/omd-quickshell-stop.sh
share/bin/omarchy-system-lock
share/bin/omarchy-system-wake
```

处理原则：

- 仍有当前用途的工具改为 manifest/registry 驱动；
- 已无调用方的工具删除；
- 不得把路径改成另一个硬编码目录后继续保留同样问题。

### P1-3 QML Service 仍直接访问外置二进制

已确认的文件包括：

```text
quickshell/services/KeyboardRemap.qml
quickshell/services/VoiceInput.qml
quickshell/services/InputMethod.qml
quickshell/services/BluetoothStatus.qml
quickshell/modules/launcher/module-actions.qml
quickshell/modules/wifi/module-actions.qml
quickshell/modules/common/functions/Session.qml
quickshell/modules/launcher/modules/appLauncher/AppLauncher.qml
```

影响：

- 对应按钮可能存在，但命令不可执行。
- Core 进程仍知道 Voice、Input Method、Bluetooth 等模块实现位置。

整改：

- 二进制路径由模块 manifest/entry 提供。
- UI 只调用 Action 或 Service API。
- 模块不存在时贡献不应进入 Registry。

### P1-4 配置和文档仍宣称有外置模块仓库

确认残留：

- `defaults/config/quickshell/config.json` 的 `modules.dir`；
- `lib/paths.sh` 的 `SUMIKA_MODULES_HOME`；
- `modules/README.md`；
- `AGENTS.md` 数据布局；
- `README.md` 的迁移说明；
- `audit-completeness-report.md` 的旧目录描述；
- `ModuleLoader.qml` 顶部注释。

整改完成后必须同步更新这些事实源，避免后续 agent 再次按旧架构恢复外置路径。

## 6. Core 内部一致性问题

### P1-5 Product floor 固定加载正确，但定义存在多份

`quickshell/core/runtime/ModuleLoader.qml:30-46` 内置：

```text
launcher
clock
notification-popup
workspaces
overview
systray
wifi
audio
power-indicator
display
```

`isEnabled()` 保证这些模块在 `modules.enabled=false` 时仍启用。根据最新确认，
这是正确的最小桌面行为，不是缺陷。

真正的问题是 product floor 还同时隐含在：

- `ModuleLoader.productFloorModuleIds`；
- 默认配置和 Bar 顺序；
- 各 module manifest；
- Core builtin Action；
- 启停脚本和应用入口。

当其中任意一处变化时，其他位置可能不一致。

整改：

- 保留 product floor，但建立一个权威定义。
- 推荐由 Core distribution manifest 声明基本组件，ModuleLoader 只读取结果。
- `modules.enabled` 改名为 `optionalModulesEnabled`，或至少在 schema 和 UI 中明确
  “关闭额外模块，最小桌面始终保留”。
- 新增 Core 基本组件时只改一个事实源。

验收：

```text
optional modules off
```

Overview、Workspace、Applications/Launcher、Wi-Fi、Audio、Display、Power 等
最小桌面仍正常；所有额外扩展均不加载。

### P1-6 `ActionManager` 与 module action provider 可能重复注册

`quickshell/core/runtime/ActionManager.qml:293-586` 直接注册大量产品行为：

- Lock、Logout、Reboot、Shutdown、Suspend、Hibernate；
- Session Save；
- Settings、Reload；
- Overview、Launcher；
- Bluetooth；
- Audio 与 Microphone；
- Brightness、Display、Scaling、Color Picker；
- Touchpad；
- Window behavior；
- Workspace layout。

这些 Action 中属于最小桌面的行为可以由 Core 提供。问题不是“Core 里出现
Audio 或 Launcher”，而是同一个行为同时可能来自 builtin、manifest 和
`module-actions.qml`，删除外置模块后还存在指向不存在脚本的 Action。

整改：

- 为每个 Action 确定唯一 owner：`core.<feature>` 或某个可选模块。
- 最小桌面 Action 可以继续内置，但不能再由 module provider 重复注册。
- Session Save、Voice、OCR、Keyboard Remap 等非最小功能若实现已删除，
  必须连同 Action 一起删除或迁入有效的可选模块。
- ActionManager 保留统一冲突检测；启动日志中重复 ID 必须为零。

验收：

- 导出 Action Registry，检查每个 ID 只有一个 owner。
- 逐个调用 Core 最小桌面 Action。
- 所有可见 Action 都有实际存在的实现。
- 删除可选模块后，不留下同名无效 Action。

### P1-7 `ServiceManager` 的 Core 与可选 Service 边界不清

`ServiceManager.qml:17-24` 已在源码注释中明确承认：

> This is NOT a full provider architecture.

当前仍直接：

```qml
import qs.services as Services
```

并把 Audio、Network、Power、Notification、MPRIS、Workspace、Brightness、
InputMethod、Tray、Bluetooth 等具体 Singleton 以 owner `core` 注册。

同时 `quickshell/services/` 仍有 29 个具体 Service，包括：

```text
Audio Battery BluetoothStatus Brightness HyprlandData InputMethod
KeyboardRemap LockService MprisController Network Notifications
PowerProfiles TrayService VoiceInput Wallpaper ...
```

Audio、Network、Power、Workspace、Brightness 等最小桌面 Provider 位于 Core
是允许的。当前问题是 29 个具体 Service 中还混有 VoiceInput、
KeyboardRemap 等已经依赖外置模块的可选功能，而且 facade、直接 singleton
import 和模块 provider 三种访问方式并存。

整改：

1. 列出 Core 最小桌面 Service 白名单。
2. 白名单 Service 可以随 Core 启动，并由 ServiceManager 统一暴露。
3. Voice、OCR、Keyboard Remap、可选 Bluetooth 工具等非最小 Service 必须
   移出或删除悬空实现。
4. 同一个 Service 只能有一种权威访问路径。
5. 可选 Service Provider 仍通过 manifest 注册和注销。

### P1-8 模块绕过 Service API

当前在 Core、Apps 和功能模块中有 21 个文件直接：

```qml
import qs.services
```

其中包括 Audio、Wi-Fi、Display、Overview、Power、Systray 和部分 Common
组件。

整改：

- Core 最小桌面组件允许使用 Core Service，但应统一通过 ServiceManager 或
 明确的稳定 API，避免一部分走 facade、一部分直接 import singleton。
- 可选模块只能依赖公开 Service API。
- 先区分 Core 与 Optional，再减少 21 个直接 import；不能机械删除导致最小
  桌面失效。

验收：

```sh
rg -l 'import qs\.services' quickshell/core quickshell/modules apps
```

结果应只包含明确列入 Core 白名单的组件和 provider adapter；可选 UI 页面和
Widget 不得直接引用 Core 私有 singleton。

## 7. 模块隔离和生命周期问题

### P1-9 Core 内置组件与可选扩展未在 Registry 中明确区分

Schema 已定义 `trustedInProcess`，架构文档也规定只有明确可信的官方模块才能
向 Core 进程加载任意 QML。

当前 10 个 manifest 都没有设置该字段。它们现在属于最小桌面，可以被视为
受信 Core 组件并加载到 Bar 进程；但 Registry 没有表达这个事实，未来加入
可选或第三方扩展时将无法区分。

影响：

- Core 内置组件和第三方模块使用同一种加载路径。
- 未来第三方 manifest 可能获得与 Core 相同的进程权限。
- 可选扩展故障隔离无法实施。

整改：

- Registry 明确记录 `origin: core|optional|third-party` 或等价字段。
- Core product floor 默认受信，不要求用户逐项配置。
- 非 Core 扩展默认不受信，只能贡献声明式数据或运行独立进程。
- 受信 Core 组件加载失败仍应显示 Error Placeholder，尽量避免 Bar 整体退出。
- `trustedInProcess` 的强制规则只针对非 Core 扩展。

### P1-10 缺少可靠的 unload 和故障隔离

当前主要依靠 `Loader` 加载贡献，但没有完整的：

- 模块健康状态；
- 加载超时；
- 崩溃/异常计数；
- quarantine；
- provider/action/widget 成组注销；
- 独立进程监督和重启策略。

`unregisterOwner()` 等局部 API 已存在，但尚未形成完整生命周期事务。

整改：

```text
discover
  -> validate
  -> register transaction
  -> activate
  -> health monitor
  -> deactivate
  -> unregister all owned contributions
```

任一步失败都必须回滚该可选模块已经注册的 Action、Service 和 Extension。
Core product floor 发生错误时进入最小安全状态并给出诊断，不能直接变成空桌面。

### P2-1 `ApplicationManager` 使用轮询等待 Registry

Registry 已提供 `registryLoaded()`，但 ApplicationManager 仍存在轮询/重试式
初始化倾向。空 Registry 是 Core 的合法状态，不应被视为“尚未完成加载”而永久
重试。

整改：

- 使用明确的 registry ready 状态和 signal。
- 区分“加载完成但为空”与“文件尚未生成”。

## 8. 目录所有权和冗余

### P2-2 `common` 混入功能专属组件

`quickshell/modules/common/` 不只是通用 UI primitive，还包含：

```text
ClockHoverPopup.qml
NotificationUtils.qml
NotificationAppIcon.qml
NotificationGroup.qml
NotificationItem.qml
NotificationListView.qml
PowerContextMenu.qml
Session.qml
OverviewSwitchingController.qml
WorkspaceNavigation.qml
BarBatteryIcon.qml
HyprlandXkbIndicator.qml
```

这些组件拥有明确功能所有者，不属于通用组件库。

整改：

- Notification 组件归 Notification 模块。
- Power/Battery 组件归 Power 模块。
- Clock 组件归 Clock 模块。
- Session 逻辑归 Session/Power 模块。
- Workspace/Overview 逻辑按宿主 API 与 Provider 职责拆分。
- `common` 只保留无业务语义的 Button、Text、List、Popup、Layout、Color、
  File 等 primitive。

### P2-3 模块内部仍有历史嵌套目录

例如：

```text
quickshell/modules/launcher/modules/appLauncher/
```

这保留了旧版“模块内再嵌 modules”的迁移结构，使 import 和所有权难以判断。

整改：

- 每个模块一个清晰根目录。
- manifest 中路径全部相对模块根。
- 禁止模块根下再次创建旧架构 `modules/<feature>` 镜像。

### P2-4 Audio 模块混入 Bluetooth Settings

`quickshell/modules/audio/settings/BluetoothPage.qml` 表明 Audio 与 Bluetooth
设置所有权仍混合。

整改：

- Bluetooth UI 和 Service 归 Bluetooth 模块。
- Audio 只能通过公开 Service/Action 跳转或关联设备，不能拥有 Bluetooth
  设置页。

### P2-5 `popupSections` 保留 Core/External 路径优先级

`ModuleLoader.popupSections` 通过路径是否包含 `"OMD/"` 判断 Core 优先于外置
模块，并硬编码 battery、inputMethod、keyboard、voice 为 singleton type。

问题：

- 路径不是可信身份。
- 外置模块已经删除。
- Core 再次知道具体业务 popup 类型。

整改：

- 冲突策略来自 Extension Point schema。
- 使用模块 trust、priority 和明确 ownership，不使用字符串路径猜测。
- Popup 类型由注册表定义，Core 只执行通用冲突规则。

## 9. 配置语义问题

### P2-6 `modules.enabled` 名称容易被误解

当前用户配置可以设置：

```json
{
  "modules": {
    "enabled": false
  }
}
```

`ModuleLoader` 会继续启用 product floor。根据最新产品定义，这是正确行为：
最小桌面不能因为关闭扩展模块而消失。

整改：

- 保留 product floor。
- 将字段重命名或补充 schema 文案，避免用户把它理解为“关闭整个桌面”。
- 建议配置结构：

```text
core.productFloor       # 发行定义，只读或高级配置
modules.optionalEnabled
modules.disabled
modules.order
```

- 如果为了兼容保留 `modules.enabled`，它必须被文档定义为
  `optional modules enabled`。
- UI 中不得使用“关闭模块系统”这种会让用户误解的标签。

## 10. 文档一致性问题

以下文档或说明互相矛盾：

- `AGENTS.md`：Core shared QML 只有 3 个，外置功能模块 27 个；
- 当前目录：13 个模块目录，其中 10 个功能 manifest；
- `modules/README.md`：全部功能位于 `$SUMIKA_MODULES_HOME`；
- 旧目标架构：Core 不拥有具体功能；
- 最新确认的产品边界：Core 必须拥有可独立使用的最小桌面；
- 实际启动脚本：同时扫描仓库内目录和已删除的外置目录。

整改顺序：

1. 先把权威架构文档改为“最小桌面 Core + 可选扩展”。
2. 决定单仓库最终目录。
3. 修改运行时只使用该目录。
4. 通过验收后再同步 `AGENTS.md`、README、目录文档和 Path API。
5. 删除 `audit-completeness-report.md` 等已经与当前目录不符的旧报告，
   或把仍有效结论合并到权威文档。

## 11. 推荐整改顺序

另一个 agent 应严格分批执行，不要一次大改。

### Phase A：恢复可安装、可诊断基线

- [ ] 修复 `Init.sh` 语法错误和过期提示。
- [ ] 修复 `omd-doctor` Path API。
- [ ] 决定并修复 Settings 入口。
- [ ] 决定并修复 Screenshot 入口。
- [ ] 为上述修复增加 shell syntax 和入口 smoke test。
- [ ] 独立 commit，不混入架构移动。

### Phase B：确定单仓库 Core 与 Optional 边界

- [ ] 固化当前最小桌面 product floor。
- [ ] 确定 Core 组件与 `modules/optional/<id>` 或等价可选模块目录。
- [ ] 只移动可选功能；不得移除 Overview、Workspace、Applications/Launcher、
  Wi-Fi、Audio、Display、Power 等最小桌面。
- [ ] 更新 manifest 相对路径。
- [ ] Registry 分别识别 Core 和 Optional 来源。
- [ ] 删除 `$SUMIKA_MODULES_HOME` 扫描、staging 和 fallback。
- [ ] 独立 commit。

### Phase C：收敛 Core 重复注册

- [ ] 为 product floor 建立唯一事实源。
- [ ] 明确 `modules.enabled` 只控制可选模块。
- [ ] 审计 builtin Action 与 module action provider，删除重复项。
- [ ] 保留最小桌面 Action；迁出已删除或可选功能 Action。
- [ ] 删除 Core 内 singleton popup 类型和路径优先级。
- [ ] 验证可选模块可独立禁用且最小桌面不受影响。
- [ ] 按功能分批 commit。

### Phase D：收敛 Core Service 和可选 Provider

- [ ] 定义 Core 最小桌面 Service 白名单。
- [ ] Audio、Network、Power、Workspace、Display 等可保留为 Core Service。
- [ ] 统一 Core Service 的访问方式，删除 facade/direct import 双轨。
- [ ] Voice、Keyboard Remap、OCR 等可选 Service 迁出或删除悬空实现。
- [ ] 每个 Service 边界修复独立 commit。

### Phase E：清理 Common 和模块所有权

- [ ] 移出 Notification 专属组件。
- [ ] 移出 Power/Clock/Session 专属组件。
- [ ] 清理 Launcher 嵌套路径。
- [ ] 分离 Audio 与 Bluetooth。
- [ ] 保证 `common` 只剩通用 primitive。

### Phase F：实施可选扩展隔离和生命周期

- [ ] Registry 区分 Core 与 Optional/Third-party。
- [ ] 对非 Core 扩展强制 `trustedInProcess`。
- [ ] 非可信复杂 UI 改为独立进程。
- [ ] 增加加载错误占位。
- [ ] 增加 owner 级事务注册和完整注销。
- [ ] 增加进程健康状态和 quarantine。
- [ ] 验证插件失败时 Bar 和 Overview 继续运行。

### Phase G：删除残留并更新文档

- [ ] `rg SUMIKA_MODULES_HOME` 清零，或只保留明确的历史迁移说明。
- [ ] 删除失效 CLI 和空入口。
- [ ] 更新 AGENTS、README、project structure 和 architecture 文档。
- [ ] 删除被权威文档取代的旧审计报告。

## 12. 验收矩阵

### 12.1 静态验收

```sh
bash -n Init.sh
bash -n bin/omd-doctor
bash -n bin/omd-settings
bash -n bin/omd-screenshot
bash -n scripts/reload-quickshell

find quickshell/modules modules/optional -name module.json -print0 2>/dev/null |
  xargs -0 -n1 bin/omd-module-validate

rg -n 'SUMIKA_MODULES_HOME|sumika-modules' \
  --glob '!docs/**' --glob '!*.md' .

rg -l 'import qs\.services' quickshell/core quickshell/modules modules/optional
```

要求：

- 所有 syntax check 成功。
- 每个 manifest 验证成功。
- 已删除的外置模块路径在运行时代码中为零。
- Core product floor 中每个 Action、Service 和 UI contribution 只有一个 owner。
- 可选 UI 模块不直接 import Core 私有 Service。

### 12.2 最小桌面验收

关闭所有可选模块或使用只包含 Core product floor 的 Registry：

- Core 可以启动。
- TopBar、Overview、Workspace 状态、Applications/Launcher、Wi-Fi、Audio、
  Display 和 Power 正常。
- 不显示 Optional contribution。
- 日志明确区分 Core component 数量和 Optional module 数量。
- 可以安全退出或重新加载 Optional Registry。

### 12.3 单个可选模块验收

在完整最小桌面上逐个只启用一个可选模块：

- 除 product floor 外，只出现该可选模块的贡献。
- Action、Popup、Service 和设置页数量符合 manifest。
- 禁用后所有 owner contribution 被注销。
- 不留下后台进程。

### 12.4 故障隔离验收

人为制造：

- manifest 无效；
- QML component 不存在；
- provider 启动失败；
- 独立模块进程退出；
- Action 超时。

要求：

- Bar 和 Overview 继续运行。
- 只禁用故障模块。
- UI 显示可定位的错误状态。
- 修复后可重新加载模块，不必重启整个 Shell。

### 12.5 图形会话验收

以下项目不能只靠 offscreen QML 测试完成：

- `hyprctl reload` 后 Bar/Overview；
- 多显示器；
- Popup；
- Settings；
- Screenshot；
- 模块启停；
- 独立进程故障隔离；
- 冷启动和重新加载。

必须在真实 Hyprland 会话执行：

```sh
hyprctl reload
bash scripts/reload-quickshell
bin/omd-doctor
```

并检查相关 user unit 日志。

## 13. 本轮验证记录

已执行：

- 10 个现有 manifest 均通过 `bin/omd-module-validate`。
- 未发现 dangling symlink。
- `bin/omd-settings`、`bin/omd-screenshot`、
  `scripts/reload-quickshell` 通过 `bash -n`。
- `Init.sh` 未通过 `bash -n`。
- `omd-doctor` 的 shell 语法本身通过，但运行依赖路径已经失效。
- 共确认 21 个 Core/UI 文件直接 import `qs.services`。
- 共确认 29 个具体 QML Service 仍位于 Core QML 根。

未完成：

- 本轮没有修改代码。
- 没有覆盖当前未提交的 `bin/omd-settings`。
- 受执行环境限制，没有把 offscreen Quickshell 结果当作真实 Hyprland
  图形会话验收。

## 14. 给整改 Agent 的约束

1. 先读本报告和两份权威架构文档。
2. 开始前执行 `git status --short`，保护用户未提交修改。
3. 每个 Phase 分开提交；Service 按垂直切片分开提交。
4. 不得删除或外移已经确认属于最小桌面的 Core 功能；修复重点是去重、
   所有权和已删除外置模块残留。
5. 不得新增另一个外置路径 fallback。
6. 不得让 UI 直接调用模块私有脚本。
7. 每个 manifest 是该模块贡献的唯一事实源。
8. GUI 未测试必须明确标记，不能写“全部完成”。
9. 完成后更新本报告中的验收项；稳定结论合并回权威文档后删除本临时审计报告。
