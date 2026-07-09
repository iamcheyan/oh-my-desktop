# Overview Performance Optimization

The workspace overview (工作区概览) felt laggy and unresponsive on weak GPUs:
it took a long time to appear after the keybind. This document records the
root-cause analysis and the fixes applied, all gated on the existing
"Performance" mode in the Display settings center
(`Persistent.states.display.optimization === "performance"`).

The three modes (High Performance / Balanced / Best Visuals) are user-
selectable in Settings → Display → Performance & Effects. Only "High
Performance" applies the optimizations below; Balanced and Best Visuals keep
the premium look.

---

## Root causes

### 1. Live `ScreencopyView` per window (dominant cost)
`OverviewWindow.qml` rendered each window preview as a `ScreencopyView` with
`live: true`. Every window on every visible workspace streamed frames
continuously. Opening the overview had to establish N Wayland screencopy
sessions at once — the dominant GPU/compositor cost on weak hardware.

### 2. `layer.enabled` + `OpacityMask` per window
Each window preview enabled `layer.enabled: true` with an `OpacityMask` for
rounded corners. This adds an offscreen render pass per window; with live
screencopy the layer texture re-rendered every frame.

### 3. Per-workspace wallpaper `Image`
Each workspace tile loaded a full wallpaper `Image` (texture upload + sampling)
even though it is mostly covered by window previews.

### 4. Window repeater instantiated in the first frame
The window `Repeater` (with its `ScreencopyView` delegates) was created in the
same frame as the workspace grid, blocking the first paint until all
previews were ready.

### 5. `Behavior` animators on the focused-workspace indicator
Six `Behavior` bindings on the indicator tracked every property change even
though their animation duration is 0 in performance mode.

---

## Fixes

All fixes are gated on `perfMode` (read from
`Persistent.states.display.optimization`), so Balanced/Best Visuals are
unaffected.

| # | Commit | Change |
|---|--------|--------|
| 1 | `0ef2fa5` | `ScreencopyView.live: false` in performance mode (single snapshot instead of a continuous stream). |
| 2 | `f436328` | `layer.enabled: false` in performance mode (square previews, no OpacityMask offscreen pass). |
| 3 | `40ba52c` | Hide the per-workspace wallpaper `Image` in performance mode (solid-color tiles). |
| 4 | `1a4213a` | Defer the window `Repeater` by 80ms in performance mode so the workspace grid paints first. |
| 5 | `f03869f` | Disable the 6 `Behavior` animators on the focused-workspace indicator in performance mode. |

---

## How to verify

1. Settings → Display → Performance & Effects → **High Perf**.
2. Trigger the overview (Super or the configured keybind).
3. The workspace grid should appear immediately; window snapshots fill in
   ~80ms later.

Switching back to **Balanced** or **Best Visuals** restores live previews,
rounded corners, wallpaper tiles, and animations.