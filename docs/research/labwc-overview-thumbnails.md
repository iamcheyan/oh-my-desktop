# labwc overview 窗口缩略图 — 结论速览（参考文档）

> 本文件是 [labwc-adaptation-feasibility.md](labwc-adaptation-feasibility.md) 的
> 通俗版结论 + 决策参考。详细协议逐条核实见那份文档（§2.2 / §2.3.1 / §4 / 附录 B）。
> 调查日期：2026-08-08。

## 一句话结论

**协议层完全可行（labwc 官方源码逐行核实），卡点在 Quickshell 客户端不认识
labwc 的窗口捕获协议**，所以当前 overview 在 labwc 下显示不了窗口缩略图。
labwc 原生 windowSwitcher（Win+Tab）自带缩略图 OSD，已配好、已可用。

## 为什么 Hyprland 下能显示，labwc 下不能

- Hyprland 有私有协议 `hyprland-toplevel-export-v1`（导出窗口画面）。
- overview 每个窗口 tile 用 Quickshell 的
  `ScreencopyView { captureSource: toplevel }` 抓这个协议。
- labwc 没有这个 Hyprland 私有协议 → 这条路断在 **Quickshell 客户端**，
  不是 labwc 不支持。

| 层 | 状态 |
|---|---|
| labwc 协议端 | ✅ 完整——`ext_foreign_toplevel_image_capture_source_manager_v1` + `ext_image_copy_capture_v1` 都在；官方源码核实捕获范围含 xdg 弹窗 / subsurface（§2.2） |
| Quickshell 客户端 | ❌ `ScreencopyView` 的 toplevel 捕获只认 `hyprland-toplevel-export-v1`；ext-image-copy-capture 后端只做**整屏输出捕获**，没接窗口级。issue [#160](https://github.com/quickshell-mirror/quickshell/issues/160) 开了一年仍 open（2026-08-08 确认） |

## 三条实现路径

| # | 路径 | 做法 | 成本 |
|---|---|---|---|
| 1 | 等上游 | Quickshell #160 落地后，现有 overview QML 一行不改直接出图 | 零代码，但时间未知，不能押注 |
| 2 | 自写协议客户端 | 自己实现 Wayland 客户端：`ext_foreign_toplevel_list` 枚举窗口 → image-capture-source 建捕获源 → image-copy-capture 拷帧 → DMA-BUF/shm 喂给 QML（QQuickImageProvider 或 Quickshell IO 机制） | 工作量大，但**唯一确定能出图**；纯客户端活、不依赖上游、协议端零阻塞 |
| 3 | 列表降级 | 用 wlr-foreign-toplevel-management（labwc 支持）拿 appId/title/图标，做点击激活/关闭的列表，无缩略图 | 现在就能做；但协议**没有 workspace 字段**，做不了"只显示当前工作区"过滤（§4） |

## 建议

- **Win+Tab 窗口切换**：直接用 labwc 原生 windowSwitcher（§2.4，已配好），别自己造。
- **overview 缩略图**：现在就要 → 路径 2；能等 → 路径 1（零成本）；过渡 → 路径 3。

## 两个容易踩的坑（已核实）

1. **`<allowedInterfaces>` 白名单陷阱（§2.3.1）**：labwc 的
   `parse_privileged_interface()` 特权协议白名单里有
   `ext_image_copy_capture_manager_v1`、`ext_foreign_toplevel_list_v1`、
   `zwlr_foreign_toplevel_manager_v1` 等，但**没有**
   `ext_foreign_toplevel_image_capture_source_manager_v1`。以后若给 rc.xml 配了
   `<allowedInterfaces>`，缩略图协议会被拒。当前 rc.xml 没配（默认全允许），所以现在没事；
   附录 B 已加警示。
2. **overview 工作区过滤**：foreign-toplevel 协议无 workspace 字段，路径 3 的
   列表式 overview 无法按工作区过滤窗口。

## 验证状态

- 本机双实例实测：labwc 官方 0.20.1 已运行，`wayland-info` 协议清单见
  feasibility 文档附录。
- Quickshell issue #160 状态：**open**（2026-08-08 再次确认）。
- labwc 官方 master `0.20.1-18-g17ad8a7b` 相对 0.20.1 的 18 个 commit 全是
  样式/翻译/零碎修复，无 capture 相关改动（§0.1）；xdg-toplevel-icon 版本标注
  已修正为"0.20.0 就有"。
