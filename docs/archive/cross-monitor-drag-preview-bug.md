# 跨屏拖拽窗口预览消失 Bug 分析与修复

## 问题现象

在双显示器环境下，从工作区概览（Overview）中拖拽窗口跨屏幕移动时：

| 操作场景 | 结果 |
|---------|------|
| 在 **内屏 (eDP-1)** 打开概览，内屏 → 外屏 | ✅ 正常 |
| 在 **内屏 (eDP-1)** 打开概览，外屏 → 内屏 | ✅ 正常 |
| 在 **外屏 (HDMI-A-1)** 打开概览，内屏 → 外屏 | ✅ 正常 |
| 在 **外屏 (HDMI-A-1)** 打开概览，外屏 → 内屏 | ❌ **窗口缩略图消失** |

只有最后一种情况会出问题——在外接显示器上打开概览，把外接显示器上的窗口拖到笔记本内屏的工作区时，窗口预览缩略图会"消失"。

---

## 硬件环境

| 显示器 | 物理分辨率 | 缩放比例 | 逻辑宽度 | 逻辑高度 | 全局坐标起始 X |
|--------|-----------|---------|---------|---------|-------------|
| eDP-1（内屏） | 3024 × 1964 | 2.0x | **1512** | 982 | 0 |
| HDMI-A-1（外屏） | 3840 × 2160 | 2.0x | **1920** | 1080 | 1512 |

> [!IMPORTANT]
> 核心差异：内屏逻辑宽度 (1512) **小于** 外屏逻辑宽度 (1920)。
> 外屏上的窗口坐标范围是 `[1512, 3432)`，内屏的坐标范围是 `[0, 1512)`。
> 外屏窗口的 X 坐标（如 1518）**几乎刚好等于**内屏的右边界（1512），只超出了 6 像素。

---

## 根因分析

### 第一层：Hyprland 不会为非活动工作区重新计算平铺布局

当用户在概览中把窗口拖到另一个显示器的工作区时，代码调用：

```javascript
Hyprland.dispatch(`hl.dsp.window.move({ workspace = ${targetWorkspace}, ... })`)
```

Hyprland 会立即将窗口分配到新的工作区和新的显示器，但 **如果目标工作区不是当前活动工作区，Hyprland 不会重新计算窗口的平铺布局**。窗口的 `workspace.id` 和 `monitor` 字段会更新，但 `at`（坐标）和 `size`（尺寸）保持不变——它们还是在旧显示器上的值。

### 第二层：跨屏坐标在新显示器上变得"越界"

假设一个窗口原来在 HDMI-A-1 上，全局坐标为 `at: [1518, 38]`：

- **移动前**：`monitorData` = HDMI-A-1（x=1512）
  - `xRel = 1518 - 1512 = 6` → 在显示器范围内 ✅
- **移动后**：`monitorData` 更新为 eDP-1（x=0）
  - `xRel = 1518 - 0 = 1518` → 超出 eDP-1 的逻辑宽度 1512 ❌

窗口的全局坐标 1518 对于 eDP-1 来说是"越界"的。

### 第三层：旧的 ±10px 阈值检测失败

之前的越界检测代码：

```javascript
property bool isCoordinatesStale: {
    const xRel = windowData.at[0] - monitorData.x;
    const yRel = windowData.at[1] - monitorData.y;
    return xRel < -10 || xRel >= monitorLogicalWidth + 10
        || yRel < -10 || yRel >= monitorLogicalHeight + 10;
}
```

对于我们的具体场景：
- `xRel = 1518`
- `monitorLogicalWidth = 1512`
- 判断：`1518 >= 1512 + 10` → `1518 >= 1522` → **false**

**只超出了 6 像素，小于 10 像素的容差阈值，所以没有被检测为越界！**

### 第四层：Clamp 产生 1 像素的"幽灵"窗口

检测没通过，坐标原样使用。接下来进入缩放和 Clamp 流程：

```
概览中每个工作区格子的宽度 (workspaceWidth) ≈ 300px
scaleX = workspaceWidth / monitorLogicalWidth = 300 / 1512 ≈ 0.198

rawLocalX = 1518 × 0.198 ≈ 300.6
localX = clamp(300.6, 0, workspaceWidth - 1) = clamp(300.6, 0, 299) = 299

targetWindowWidth = clamp(rawWindowWidth, 1, workspaceWidth - localX)
                  = clamp(~380, 1, 300 - 299)
                  = clamp(~380, 1, 1)
                  = 1
```

**窗口被渲染成了 1 像素宽的不可见线条。**

用户看到的是一个空白的工作区——但实际上窗口就在那里，只是宽度被压缩到了 1 像素。

### 为什么反方向（内屏 → 外屏）不会出问题

从 eDP-1（逻辑宽度 1512）拖到 HDMI-A-1（逻辑宽度 1920）：

- 内屏窗口坐标如 `at: [6, 38]`
- 移动后 `monitorData` 变为 HDMI-A-1（x=1512）
- `xRel = 6 - 1512 = -1506`
- 判断：`-1506 < -10` → **true** ✅

偏移量高达 -1506 像素，远远超出了 ±10 的阈值，所以旧代码能正确检测到并执行居中纠偏。

> [!NOTE]
> **不对称性的本质**：内屏比外屏窄。从宽屏移到窄屏时，坐标只越界了几个像素（窄屏宽度 ≈ 宽屏起始 X），阈值检测不到。从窄屏移到宽屏时，坐标偏移了一千多像素，很容易检测到。

---

## 修复方案

### 旧方案的缺陷

基于「固定像素阈值」的越界检测天然是脆弱的：

- 阈值太小（如 10px）：漏检边界附近的越界（本 Bug）
- 阈值太大（如 100px）：误检合法的靠近边缘的正常窗口
- 任何固定阈值都无法适应所有显示器分辨率组合

### 新方案：渲染退化检测

不再猜测"坐标越界了多少像素"，而是直接计算：**如果按真实坐标渲染，最终的窗口预览会不会退化到不可见？**

```javascript
// Raw coordinate relative to the monitor the window claims to be on.
// These may be stale after a cross-monitor move — Hyprland does not
// re-tile windows on inactive workspaces.
property real rawRelX: (windowData?.at[0] ?? 0) - (monitorData?.x ?? 0)
                       - (monitorData?.reserved[0] ?? 0)
property real rawRelY: (windowData?.at[1] ?? 0) - (monitorData?.y ?? 0)
                       - (monitorData?.reserved[1] ?? 0)
property real rawW: windowData?.size[0] ?? 800
property real rawH: windowData?.size[1] ?? 600

// After scaling and clamping, would this window be too small to see?
property bool isRenderDegenerate: {
    const clampedX = Math.max(0, Math.min(
        rawRelX * root.scaleX, Math.max(0, workspaceWidth - 1)));
    const visibleW = Math.min(
        rawW * root.scaleX, Math.max(1, workspaceWidth - clampedX));
    const clampedY = Math.max(0, Math.min(
        rawRelY * root.scaleY, Math.max(0, workspaceHeight - 1)));
    const visibleH = Math.min(
        rawH * root.scaleY, Math.max(1, workspaceHeight - clampedY));
    // If either dimension is less than 10% of the workspace box,
    // the window is effectively invisible — treat it as degenerate.
    return visibleW < workspaceWidth * 0.10
        || visibleH < workspaceHeight * 0.10;
}
```

当检测到退化时，将窗口居中显示在工作区格子中：

```javascript
property real effectiveW: isRenderDegenerate
    ? Math.min(rawW, monitorLogicalWidth) : rawW
property real effectiveH: isRenderDegenerate
    ? Math.min(rawH, monitorLogicalHeight) : rawH
property real effectiveRelX: isRenderDegenerate
    ? (monitorLogicalWidth - effectiveW) / 2 : rawRelX
property real effectiveRelY: isRenderDegenerate
    ? (monitorLogicalHeight - effectiveH) / 2 : rawRelY
```

### 为什么新方案是正确的

1. **不依赖任何固定像素阈值**——无论两个显示器的分辨率差距是 6px 还是 6000px，只要最终渲染尺寸退化到不可见，就会自动纠正。

2. **不会误触发**——一个正常位置的窗口，即使靠近边缘，只要渲染后仍然占据工作区格子 10% 以上的面积，就不会被干预。

3. **自愈性**——当 Hyprland 最终重新计算了平铺布局（用户切换到该工作区时），窗口坐标会更新为正确值，`isRenderDegenerate` 自动变为 `false`，回到精确渲染。

---

## 受影响的文件

| 文件 | 修改内容 |
|------|---------|
| [OverviewWindow.qml](file:///home/tetsuya/development/OMD/quickshell/modules/overview/OverviewWindow.qml#L46-L92) | 替换坐标越界检测逻辑为渲染退化检测 |

## 相关机制

- **Hyprland 平铺布局延迟**：窗口被 `movetoworkspace` 到非活动工作区时，Hyprland 不会立即重新计算平铺坐标。只有当该工作区被激活（成为 `activeWorkspace`）后，布局才会被重新计算。
- **`hyprctl clients -j` 的坐标含义**：返回的 `at` 字段是窗口在全局坐标空间中的绝对位置，而非相对于其所属显示器的相对位置。
- **概览窗口预览的渲染流程**：`OverviewWindow.qml` 根据 `windowData.at` 计算窗口在工作区格子中的位置，通过 `scaleX`/`scaleY` 将逻辑像素映射到格子像素，最后通过 `localX`/`localY` 和 `targetWindowWidth`/`targetWindowHeight` 的 Clamp 确保窗口不超出格子边界。
