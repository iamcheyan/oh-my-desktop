# Overview 多显示器与工作区逻辑说明

> 文档目的：梳理 **原版 ii**、**我们改动后的实现**，以及 **Hyprland 多显示器工作区模型** 之间的关系，便于判断当前「按显示器 N+1」方案哪里出了问题。
>
> 撰写时环境快照（`hyprctl`）：
>
> ```
> id=1 monitor=eDP-1
> id=2 monitor=HDMI-A-1
> id=3 monitor=HDMI-A-1
> id=4 monitor=HDMI-A-1
>
> eDP-1:      activeWs=1
> HDMI-A-1:   activeWs=2
> ```

---

## 1. 先理解 Hyprland：工作区不是「每块屏一套编号」

Hyprland 里 **workspace id 是全局的**（整个会话共用 1、2、3…），每个 workspace 对象上有一个 `monitor` 字段，表示 **该工作区当前绑定在哪块物理屏上**。

```bash
hyprctl workspaces -j   # 每个元素: { id, name, monitor, ... }
hyprctl monitors -j     # 每个元素: { name, activeWorkspace: { id }, ... }
```

要点：

| 概念 | 含义 |
|------|------|
| workspace id | 全局唯一编号，不是「显示器本地的 1、2、3」 |
| workspace.monitor | 这个 id **此刻** 显示在哪块屏（`eDP-1`、`HDMI-A-1` 等） |
| focus workspace N | 切到全局 id=N；若不存在则 **按需创建**，并绑到 **当前焦点显示器**（取决于 Hyprland 规则/配置） |
| `initial_workspace_tracking = false` | 你的 `general.lua` 里关闭了初始工作区跟踪，多屏绑定行为更「自由」 |

因此：**「每个显示器单独计算」在 UI 层可以做，但在 Hyprland 层仍共享同一套 id 池。** 这是后续很多「看起来不对」的根源。

---

## 2. 原版 ii Overview（改动前）

涉及文件：

- `ii/modules/ii/overview/Overview.qml`
- `ii/modules/ii/overview/OverviewWidget.qml`
- `ii/services/HyprlandData.qml`
- `ii/modules/common/Config.qml`（`overview.rows/columns` 等）

### 2.1 只有一个 Overview 面板，跟随焦点显示器

```qml
// Overview.qml
property var focusedScreen: Quickshell.screens.find(
    s => s.name === Hyprland.focusedMonitor?.name) ?? ...

PanelWindow {
    screen: overviewScope.focusedScreen   // 面板画在「当前焦点屏」上
    ...
    OverviewWidget { screen: panelWindow.screen }
}
```

- 全系统 **只有一个** `PanelWindow` 实例（`IllogicalImpulseFamily.qml` 里 `PanelLoader { component: Overview {} }`）。
- 打开 Overview 时，面板出现在 **Hyprland.focusedMonitor** 对应的那块 Quickshell `screen` 上。
- `OverviewWidget` 通过 `Hyprland.monitorFor(screen)` 拿到 **这块屏** 的 `HyprlandMonitor`。

**原版并没有「每块屏各画一个 Overview」**，而是「跟谁焦点走」。

### 2.2 固定 2×5 网格 + 按 id 分页（与显示器无关）

配置默认：`rows: 2, columns: 5` → 每页 **10 格**。

```qml
// OverviewWidget.qml（原版逻辑，现已改掉）
readonly property int workspacesShown: rows * columns   // 10
readonly property int workspaceGroup: floor((highlightedWorkspaceId - 1) / workspacesShown)

// 每格显示的工作区编号：
workspaceValue = workspaceGroup * workspacesShown + getWsInCell(row, col)
```

行为：

- 焦点在 ws 1–10 → 网格显示 **1…10**
- 焦点在 ws 11–20 → 网格显示 **11…20**
- **普通模式**：10 格 **全部画出**，不管 Hyprland 里是否存在、是否属于当前显示器
- **窗口缩略图**：只过滤「id 落在当前 workspaceGroup 这一页」，**不按 monitor 过滤**

### 2.3 高亮与点击

- 高亮框：`highlightedWorkspaceId` = 该屏 `monitor.activeWorkspace.id`（clamp 到 1–100）
- 点击格子：`hl.dsp.focus({ workspace = N })` 并 **关闭 Overview**

### 2.4 原版没有的东西

- 没有「每显示器工作区列表」
- 没有「N+1 尾随空位」
- 没有滚轮/方向键在 Overview 内切换（这是我们后来加的）
- Alt+Tab 模式是后来集成的（见第 4 节）

---

## 3. Hyprland 侧：你的键位与分组

`~/.config/hypr/hyprland/lib/init.lua`：

```lua
function workspace_in_group(i)
    local curr = hl.get_active_workspace().id
    return math.floor((curr - 1) / workspaceGroupSize) * workspaceGroupSize + i
end
```

`workspaceGroupSize = 10`（`variables.lua`）。

Super+1~0 只在 **当前 id 所在的 10 一组** 内跳，与 Overview 的 2×5 分页概念一致，但同样是 **全局 id**，不是 per-monitor 本地编号。

---

## 4. 我们已做的改动（按时间）

### 4.1 Alt+Tab 工作区切换（较早）

文件：`Overview.qml`、`OverviewWidget.qml`、`HyprlandData.workspaceIdsOnMonitor()`

- 打开 Alt+Tab Overview，只在 **当前焦点显示器** 上的工作区之间循环
- 列表来源：`hyprctl workspaces` 里 `ws.monitor === focusedMonitorName` 的 id，排序
- 网格：**仍用原版固定 2×5**，但 **隐藏** 不属于本屏、且无窗口、且非当前选中的格子

```qml
visible: !overviewAltTabMode || (
    workspaceOnThisMonitor && (
        workspaceValue === highlightedWorkspaceId || workspaceHasContent
    )
)
```

### 4.2 普通 Overview：滚轮 + 方向键（中期）

- `GlobalStates.overviewFocusedWorkspaceId`：Overview 打开时的「导航焦点」
- 键盘焦点在网格导航层（搜索框为空时）
- dispatch 改为 Lua 语法：`hl.dsp.focus({ workspace = N })`

### 4.3 普通 Overview：每显示器 N+1 动态网格（最近）

文件：`HyprlandData.overviewWorkspaceEntriesOnMonitor()`、`OverviewWidget` 网格重写、`Overview.qml` 导航改写

**目标**：每块屏只显示「该屏已有工作区 + 1 个 `+` 空位」，滚轮/方向键只在此列表内循环。

---

## 5. 当前实现详解

### 5.1 数据：每显示器工作区列表 + 尾随空位

`HyprlandData.qml`：

```javascript
function workspaceIdsOnMonitor(monitorName) {
    return workspaces
        .filter(ws => ws.monitor === monitorName && isRegularWorkspace(ws))
        .map(ws => ws.id)
        .sort((a, b) => a - b);
}

function overviewWorkspaceEntriesOnMonitor(monitorName) {
    const ids = workspaceIdsOnMonitor(monitorName);
    const model = ids.map(id => ({ id, isTrailingEmpty: false }));

    // 若列表为空：fallback 到该屏 activeWorkspace.id，否则 [1]
    if (model.length === 0) { ... }

    const trailingId = maxId + 1;   // maxId = 该屏已有 entry 的最大 id
    if (trailingId <= 100 && !ids.includes(trailingId))
        model.push({ id: trailingId, isTrailingEmpty: true });

    return model;
}
```

按上文环境快照，两屏模型应为：

| 显示器 | `workspaceIdsOnMonitor` | `overviewEntries`（普通模式） |
|--------|-------------------------|-------------------------------|
| eDP-1 | `[1]` | `[{1}, {2, trailing}]` → **2 格** |
| HDMI-A-1 | `[2,3,4]` | `[{2},{3},{4},{5, trailing}]` → **4 格** |

### 5.2 显示：动态 GridLayout

`OverviewWidget.qml`：

```javascript
readonly property var overviewEntries: GlobalStates.overviewAltTabMode
    ? /* 本屏有窗或当前选中的 id */
    : HyprlandData.overviewWorkspaceEntriesOnMonitor(root.monitor?.name);

readonly property int overviewGridColumns: min(max(length, 1), Config.options.overview.columns);
```

- 普通模式：`Repeater` 遍历 `overviewEntries`，尾随格显示 `+`
- 窗口缩略图：只显示 `overviewEntryIds` 中且 `workspaceBelongsToMonitor(id, 本屏名)` 的窗

### 5.3 导航：在 entry 列表下标上循环

`Overview.qml` / `OverviewWidget.cycleOverviewWorkspace`：

```javascript
idx = (idx + dir + model.length) % model.length;
focus(model[idx].id);
```

左右键：±1；上下键：±columns（在 **列表下标** 上，不是全局 id ±1）。

### 5.4 点击「+」

```javascript
GlobalStates.overviewOpen = false;
Hyprland.dispatch(`hl.dsp.focus({ workspace = ${trailingId} })`);
```

关闭 Overview，并 focus 到 `maxId + 1`。

---

## 6. 多显示器端到端数据流（当前）

```
用户按 Super+Tab
    → GlobalStates.overviewOpen = true
    → panelWindow.screen = Quickshell 里与 Hyprland.focusedMonitor 同名的 screen
    → OverviewWidget.monitor = Hyprland.monitorFor(该 screen)
    → overviewEntries = overviewWorkspaceEntriesOnMonitor(monitor.name)
    → GridLayout 画出 N+1 格

用户滚轮 / 方向键
    → overviewModelForFocusedMonitor()  // 用 focusedMonitorName()，不是 Widget 的 monitor
    → 在 model 内 cycle
    → dispatchFocusWorkspace(id)

用户点击 +
    → 关闭 Overview
    → focus(maxId+1)
    → Hyprland 创建/切换全局 workspace
    → hyprctl workspaces 更新（异步，经 HyprlandData Process）
```

注意两个「monitor」来源：

| 用途 | 用的 monitor |
|------|----------------|
| 画网格、窗口归属 | `OverviewWidget` 的 `root.monitor`（= 面板所在 screen） |
| 键盘导航 `overviewModelForFocusedMonitor` | `Hyprland.focusedMonitor` |

在 Overview **打开期间** 两者应相同；若 Hyprland 在 focus 后 **立刻切了焦点屏**，两者会短暂不一致。

---

## 7. 你反馈的现象：「一直点 +，数字 5 6 7 8 9 10 增加，但只显示一格」

### 7.1 可能原因 A：全局 id 与 per-monitor 列表的矛盾（最可能）

场景：**在内屏 eDP 上操作**，Hyprland 只有 `ws 1` 属于 eDP。

1. 模型：`[1]` + 尾随 `[2]`，界面上 **2 格**（若你只注意到 1 格，见原因 B/C）
2. 点 `+` → `focus workspace 2`
3. 但 **id=2 可能已被 HDMI 占用**（见环境快照），Hyprland 会 **切到外屏的 ws 2**，而不是「给 eDP 新建一个本地 ws 2」
4. `workspaceIdsOnMonitor("eDP-1")` **仍然只有 [1]**
5. 再次打开 Overview（若仍在内屏）：尾随 **仍是 2**，不会变成 3、4、5…

若数字一直涨到 5–10，说明 **某处仍在用「全局 maxId」或「id 递增 focus」**，而不是「该屏列表变长」。例如：

- 反复 focus 2、3、4… 时，Hyprland 在 **外屏** 上创建 ws，eDP 列表不变
- 高亮/焦点 id 在变（`overviewFocusedWorkspaceId` 或 `effectiveActiveWorkspaceId`），但 **网格 entry 数量不变**

### 7.2 可能原因 B：点 + 会关闭 Overview，看不到网格变长

每次点击 `+` 都会 `overviewOpen = false`。用户需要 **再次 Super+Tab** 才能看网格是否增加。若创建的工作区没绑回当前屏， reopen 后仍只有原来的格数。

### 7.3 可能原因 C：`hyprctl` 刷新延迟

`HyprlandData` 通过 `Process` 拉 `hyprctl workspaces -j`，在 `onRawEvent` 时 `updateAll()`。新建 workspace 后，若 UI 绑定没及时依赖到 `HyprlandData.workspaces` 的变化，**短暂仍显示旧列表**。

### 7.4 可能原因 D：显示器名不一致

过滤条件：`ws.monitor === monitorName`。

- Hyprland：`eDP-1`、`HDMI-A-1`
- Quickshell `Hyprland.monitorFor(screen).name` 必须与之一字不差

若不匹配 → `workspaceIdsOnMonitor` 返回 `[]` → fallback 成 `[activeId]` 或 `[1]` → **永远只有 1 个真实格 + 1 个 +**。

### 7.5 可能原因 E：与 TWM 参考的结构性差异

TWM `WorkspaceOverview.qml` 的 N+1 是 **全局** 的：

```javascript
// 所有 workspaces 排序后，maxWsId+1 作为 trailing
for (workspaces) model.push({ id: ws.id });
model.push({ id: maxWsId + 1, isTrailingEmpty: true });
```

我们改成 **per-monitor** 后，`maxId` 只在该屏已有 id 上取 max。  
在 **全局 id 已被另一块屏占用** 时，`maxId+1` 可能：

- 跳号（2 在 HDMI 上，eDP 尾随仍是 2）
- focus 时切屏，而不是扩列表

---

## 8. 原版 vs 当前：行为对照表

| 维度 | 原版 ii | 当前实现 |
|------|---------|----------|
| 面板数量 | 1 个，跟焦点屏 | 同左 |
| 普通模式网格 | 固定 2×5，共 10 格 | 动态，N+1 格 |
| 格子显示谁 | 按 **全局 id 分页** 1–10, 11–20… | 按 **该屏 monitor 字段** 过滤 |
| 滚轮/方向键 | 无 | 在 **该屏 model** 内 cycle |
| 尾随空位 | 无 | `max(该屏 ids)+1`，显示 `+` |
| Alt+Tab | 无 → 后有 | 本屏 id 列表，隐藏空格子 |
| workspace id 语义 | 全局 | 仍全局（Hyprland 未改） |

---

## 9. 当前设计的核心矛盾（待你确认方向）

你想要的体验：

> 每块屏有自己的 1、2、3…，有 4 个就显示 5 格，只在里面轮换，永远留一个空的。

Hyprland 实际模型：

> 全局 1、2、3…，每个 id 同一时刻只属于一块屏；id 可被另一块屏先占用。

要在 UI 上做到「每屏独立计数」，必须额外约定一层映射，例如：

1. **显示器本地槽位**（1…N）映射到全局 id（实现复杂，需跟 Hyprland 绑定规则同步）
2. **接受全局 id**，但 trailing 用「该屏 maxId+1 **且未被任何屏占用**」或「该屏 maxId+1 **且 focus 时强制绑到本屏**」的 dispatch
3. **退回 TWM 式全局 N+1**（不 per-monitor），多屏只过滤窗口缩略图
4. **每块屏一个独立 Overview 实例**（Quickshell 多 `PanelWindow`），各读各屏 model——仍不解决 id 池共享

---

## 10. 相关代码索引

| 文件 | 职责 |
|------|------|
| `ii/services/HyprlandData.qml` | `workspaceIdsOnMonitor`, `overviewWorkspaceEntriesOnMonitor`, `workspaceBelongsToMonitor` |
| `ii/modules/ii/overview/Overview.qml` | 单面板、焦点屏同步、键盘导航、Alt+Tab 状态机 |
| `ii/modules/ii/overview/OverviewWidget.qml` | 动态网格、缩略图布局、滚轮、点击 |
| `ii/GlobalStates.qml` | `overviewOpen`, `overviewFocusedWorkspaceId`, Alt+Tab 状态 |
| `ii/modules/common/Config.qml` | `overview.rows/columns/order*` |
| `~/.config/hypr/hyprland/lib/init.lua` | `workspace_in_group` |
| `~/dotfiles/TWM/qs/WorkspaceOverview.qml` | 全局 N+1 参考实现 |

---

## 11. 建议的下一步（供你拍板）

1. **先确认 bug 复现屏**：点 `+` 时是 eDP 还是 HDMI？每次 reopen 后 `hyprctl workspaces -j` 里 id 和 monitor 分别是什么？
2. **确认你想要的 id 语义**：每屏本地 1…N，还是继续全局 id 只过滤显示？
3. **若坚持 per-monitor N+1**：focus 新工作区时可能需要额外 dispatch（例如先 `focus monitor` 再 `focus workspace empty` / 或 Hyprland 0.39+ 的 per-monitor workspace 配置），避免 trailing id 与另一块屏冲突。

你看完这份文档后，可以告诉我倾向哪种方向，再改实现。