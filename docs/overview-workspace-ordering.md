# Overview 工作区切换：Win11 Alt+Tab 逻辑

## Win11 Alt+Tab 核心机制

### MRU（Most Recently Used，最近使用优先）

任务列表按 **Z-order**（窗口堆叠顺序）排列，等价于 **最近使用优先**：
- 最近使用的窗口 → 第一位
- 次近使用的窗口 → 第二位
- 以此类推

### 关键行为

1. **打开切换器**：按 Alt+Tab，列表出现，**当前活动窗口 A 排第一**，光标初始在**第二位**（下一个最近的窗口）

2. **Tab 导航**：按 Tab 前进，Shift+Tab 后退。列表顺序在打开期间**不变**

3. **释放 Alt = 提交**：选中的窗口成为新的活动窗口，被移到 Z-order 顶端（MRU 第一位）

4. **下次打开**：列表按新的 MRU 顺序排列。刚切换到的窗口排第一，之前的窗口降到第二位

### 来回切换示例

假设有窗口 `A B C`，当前在 A：

```
第1次 Alt+Tab:  列表 [A B C], 光标在B → 释放 → 切换到B
第2次 Alt+Tab:  列表 [B A C], 光标在A → 释放 → 切换回A
第3次 Alt+Tab:  列表 [A B C], 光标在B → 释放 → 切换到B
...
```

**快速 Alt+Tab（按一下就释放）= 光标停第二位 = 永远在两个最近任务间来回切换。**

### Tab 多次切换示例

假设列表 `A W Z E U B C`，当前在 A，想切到 U：

```
Alt+Tab+Tab+Tab+Tab (光标移到U) → 释放 → 切换到U
下次打开: 列表 [U A W Z E B C], 光标在A
Alt+Tab+Tab+Tab+Tab (光标移到E) → 释放 → 切换到E
下次打开: 列表 [E U A W Z B C], 光标在U
```

**被切换到的窗口→第一位，之前的第一位→第二位，其余按原 MRU 顺序保持。**

## 映射到 Overview 工作区

### 当前实现 vs Win11

| | Win11 | 当前 overview |
|---|---|---|
| 排序依据 | 完整 MRU 顺序（Z-order） | 单一锚点 + id 升序 |
| 切换后 | 选中项→第一位，之前项→第二位 | 选中项→第一位，其余按 id |
| 来回切换 | 天然支持（两位间反复） | 需要恰好选中第二位才行 |

### 实现方案

将 `GlobalStates.overviewAnchorWorkspaceId`（单一锚点）升级为
`GlobalStates.overviewWorkspaceMru`（工作区使用顺序数组）。

#### MRU 列表维护

- **初始化**：首次启动/锚点未初始化时，按 id 升序填充所有可见工作区
- **切换工作区时**（overview 关闭、点击工作区格、点击窗口）：
  1. 从 MRU 列表中移除选中的工作区 id
  2. 将其 `unshift` 到列表头部
- **overview 打开期间**：MRU 列表**冻结**，不随高亮变化
  （等价于 Win11 "列表顺序在打开期间不变"）

#### overview 渲染

`overviewWorkspaceEntriesGlobal()` 按 MRU 顺序排列工作区：

```
function overviewWorkspaceEntriesGlobal() {
    // 1. 获取所有有窗口的工作区（id 升序）
    // 2. 按 overviewWorkspaceMru 重排序：MRU 靠前的排前面
    // 3. 末尾追加 trailing empty 占位
}
```

#### 导航逻辑

`navigateOverviewByIndex(delta)` 基于 MRU 排序后的列表 index 做模运算：
- Tab（+1）= MRU 列表中的下一个
- Shift+Tab（-1）= MRU 列表中的上一个
- 打开时光标初始在第二位（Win11 行为）

#### 光标初始位置

Win11 打开 Alt+Tab 时光标在**第二位**（不是第一位）。
当前 overview 打开时 `overviewFocusedWorkspaceId = currentWorkspaceId()`，
即光标在第一位（当前工作区）。

要完全模拟 Win11，需要：
- overview 打开时光标初始在 **MRU 第二位**（次最近的工作区）
- 这样快速 Tab+释放 = 切到次最近的工作区
- 再次打开 = 刚切换到的工作区成第一位，之前的成第二位 → 来回切换

但当前 overview 的 grab 模式已经实现了类似行为：
`openGrabbedMode(dir)` 会立即 cycle 一次，等价于光标从第一位移到第二位。
所以保持现有 grab 模式即可。

#### 锚点更新时机

与之前一致，只在 overview 关闭时更新 MRU：
- `Overview.qml onOverviewOpenChanged` 关闭分支：
  把停留的工作区移到 MRU 头部
- `OverviewWidget.qml` 点击工作区格/窗口：
  同样更新 MRU

## 注意事项

- `isTrailingEmpty` 占位不参与 MRU，永远在末尾
- MRU 列表中可能包含已关闭的工作区 id，渲染时需过滤
- 多显示器：MRU 是全局的，跨显示器切换同样更新
- 拖拽落点用 `modelData.id` 匹配，与 MRU 顺序无关