# Sumika Shell → KDE / 其他 Wayland 合成器协议支持调查

调查日期：2026-08-08（KDE 部分）/ 2026-08-09（合成器对照部分）
核实方式：全部按**官方源码**逐条核实（Quickshell master、KWin master、wlroots master、
Hyprland main、niri main、cosmic-comp master、mutter main、weston master），
无二手资料结论。

回答的问题：
1. Quickshell（Sumika Shell 的框架）在 KDE Plasma Wayland 下能不能跑？窗口截图/缩略图
   拿不拿得到？（→ §2）
2. 除 Hyprland 外，还有哪些 Wayland 桌面环境/合成器提供了 Quickshell 需要的标准协议
   （"像 Hyprland 一样"）？（→ §3、§4）

参考文档：[labwc 适配可行性调查](labwc-adaptation-feasibility.md)（窗口缩略图协议栈、
Quickshell #160 分析见该文 §2）。

---

## 1. Quickshell 实际消费的协议（先定死标准）

Quickshell 是纯 Wayland 客户端，不依赖任何合成器 IPC。它通过 QWaylandClientExtension
绑定以下协议（quickshell-mirror/quickshell **master**，≥ v0.3.0）：

| Quickshell 能力 | 协议 | 官方源码 |
|---|---|---|
| `PanelWindow`（bar/弹窗） | `zwlr-layer-shell-v1` | `src/wayland/wlr_layershell/`（编译开关 `QS_WAYLAND_WLR_LAYERSHELL`） |
| `ToplevelManager`（窗口列表/激活/关闭） | **`zwlr-foreign-toplevel-management-v1` v3，唯一** | `src/wayland/toplevel/wlr_toplevel.cpp` |
| `ScreencopyView` **输出**捕获 | `ext-image-copy-capture-v1` 优先，其次 `zwlr-screencopy-v1` | `src/wayland/screencopy/manager.cpp`（`createContext`） |
| `ScreencopyView` **toplevel** 捕获 | **`hyprland-toplevel-export-v1`，唯一** | `src/wayland/screencopy/hyprland_screencopy/hyprland_screencopy.cpp` |
| `WlSessionLock`（锁屏） | `ext-session-lock-v1` | `src/wayland/session_lock/` |
| Quickshell.Hyprland 模块 | hyprland IPC + `hyprland-global-shortcuts` / `hyprland-focus-grab` 等 | `src/wayland/hyprland/` |

两个关键事实（决定整个对照表）：

1. **`ToplevelManager` 只认 `zwlr-foreign-toplevel-management-v1`**，不认新版
   `ext-foreign-toplevel-list-v1`。只实现 ext 版列表协议的合成器（如 cosmic-comp），
   Quickshell 的窗口列表依然不可用。
2. **toplevel 像素捕获只有 `hyprland-toplevel-export-v1` 一个后端**。
   `ext-image-copy-capture` 后端目前只做**输出**捕获（`IccOutputSourceManager::captureOutput`），
   没有消费 `ext-foreign-toplevel-image-capture-source-v1`——这正是 Quickshell
   issue #160（open，最后更新 2026-06-27）。→ **当前任何非 Hyprland 合成器上，
   `ScreencopyView { captureSource: toplevel }` 都出不了缩略图**。

---

## 2. KDE（KWin）研究

### 2.1 结论

**Bar 能跑，窗口列表/截图能力全灭**。KWin 实现了 Quickshell 挂载 bar 所需的
`wlr-layer-shell-v1`，但窗口枚举（foreign-toplevel 两版都无）和图像捕获
（wlr-screencopy / ext-ICC 都无）全部缺席，且官方**明确拒绝**实现
（Bug 502647 标记 RESOLVED/INTENTIONAL，理由"已有 KDE 私有窗口管理协议"）。

与 labwc 是**两种不同性质的墙**：
- labwc：协议齐全，Quickshell 没消费（#160，等上游落地即可）。
- KDE：协议缺失，KWin 拒绝补齐（自有一套私有体系），Quickshell 侧无解。

### 2.2 协议矩阵（KWin master，`src/wayland/` 共 211 个文件逐一比对）

| 协议 | KWin | 源码证据 |
|---|---|---|
| `zwlr-layer-shell-v1` | ✅ | `src/wayland/layershell_v1.cpp` |
| `zwlr-data-control-v1` | ✅ | `src/wayland/datacontroldevice_v1.cpp`（wl-copy 可用） |
| `zwlr-foreign-toplevel-management-v1` | ❌ | 无实现文件；KWin 用私有 `org_kde_plasma_window_management`（`plasmawindowmanagement.cpp`） |
| `ext-foreign-toplevel-list-v1` | ❌ | 无 |
| `zwlr-screencopy-v1` | ❌ | 无 |
| `ext-image-capture-source-v1` / `ext-image-copy-capture-v1` | ❌ | 无 |
| `hyprland-toplevel-export-v1` | ❌ | 无 |
| `ext-session-lock-v1` | ❌ | 自有 `lockscreen_overlay_v1`（kscreenlocker 用） |
| `zwp-virtual-keyboard-v1` | ❌ | 无；[Bug 512996](https://bugs.kde.org/show_bug.cgi?id=512996) 官方方向 libei（`eitype`/`ydotool` 替代 wtype） |
| `ext-workspace-v1` | ❌ | 自有 `plasmavirtualdesktop` |

其他 KWin 私有协议：`org_kde_plasma_shell`（`plasmashell.cpp`）、
`zkde_screencast_unstable_v1`（见下）、`xdg_toplevel_icon_v1`、`xdg_toplevel_tag_v1`、
`xdg_toplevel_drag_v1`、`ext_background_effect_v1` 等。

**使用注意**：KWin 侧用 layer-shell 需 Plasma **Wayland** 会话（X11 会话下
`QT_QPA_PLATFORM` 是 xcb，PanelWindow 不生效）；KWin 对 exclusiveZone/键盘焦点/
弹窗/全屏的处理与 wlroots 有差异。

### 2.3 KWin 自己拿窗口缩略图的机制（官方源码核实）

Plasma 6 任务栏能看到 Wayland 窗口预览，但**全部是 KDE 私有路径**，Quickshell
无法复用：

1. **`zkde_screencast_unstable_v1` 窗口流 + PipeWire**（任务栏 tooltip 预览的真实机制）
   - 客户端：plasma-workspace `libtaskmanager/screencasting.cpp` 的
     `createWindowStream(uuid)` → KWin `src/plugins/screencast/`
     （`screencaststream.cpp`，经 PipeWire 推窗口画面）。
   - 客户端需在 `.desktop` 声明 `X-KDE-Wayland-Interfaces=zkde_screencast_unstable_v1`
     才被 KWin 放行（`screencasting.cpp` 构造函数的 qWarning 提示）。
   - 这是**按 uuid 抓窗口画面**的唯一 KWin 方式，但协议私有 + 白名单。
2. **KWin scripting `WindowThumbnail`**（`src/scripting/windowthumbnailitem.{h,cpp}`，
   QML 模块 `org.kde.kwin`）：合成器**内部** GL 离屏渲染窗口到纹理，只有 KWin
   脚本/特效（经 D-Bus `org.kde.kwin.Scripting`）能用，外部 Wayland 客户端不可达。
3. **PlasmaCore `WindowThumbnail`**（plasma-framework
   `src/declarativeimports/core/windowthumbnail.h`）：头文件注释明确写着
   *"live updating thumbnails are only implemented on the X11 platform"*——
   Wayland 下回退成窗口图标。

### 2.4 对 Sumika 的推论

| 能力 | KDE 下 |
|---|---|
| bar/popups（layer-shell） | ✅ 可跑（Plasma Wayland） |
| overview / ToplevelManager | ❌ 协议缺失 |
| ScreencopyView（输出或窗口） | ❌ 协议缺失 |
| 窗口缩略图 | 仅 KDE 私有路径（zkde_screencast+PipeWire，或 scripting），需写 KDE 专属客户端，非 Quickshell 能力 |
| sasayaki 焦点探测 | ⚠️ 已有 `resolveKWinFocus` 路径；但 wtype 注入不可用（无 virtual-keyboard），需 ydotool（uinput）/ eitype（libei） |

---

## 3. 合成器协议对照矩阵

每格 = 官方源码核实结论。✅ = 实现；❌ = 未实现；`ext-list` = `ext-foreign-toplevel-list-v1`；
`wlr-ftm` = `zwlr-foreign-toplevel-management-v1`；`ICC` = `ext-image-copy-capture-v1`
（+ `ext-image-capture-source-v1`）；`TLE` = `hyprland-toplevel-export-v1`；
`vkey` = `zwp-virtual-keyboard-v1`；`dctl` = `zwlr-data-control-v1`；
`lock` = `ext-session-lock-v1`。

| 合成器 | layer-shell | wlr-ftm | ext-list | wlr-screencopy | ICC | TLE | lock | vkey | dctl | Quickshell 结论 |
|---|---|---|---|---|---|---|---|---|---|---|
| **wlroots 系**（sway / labwc 0.20+ / wayfire / river / cage…） | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ | ✅ | bar ✅ / 窗口列表 ✅ / 输出捕获 ✅ / 锁屏 ✅ / wtype ✅；**toplevel 缩略图 ❌**（#160） |
| **Hyprland** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | 全功能（现状基线，唯一有 TLE） |
| **niri** | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | bar ✅ / 列表 ✅ / 输出捕获 ✅；锁屏 ❌ / wtype ❌ / 缩略图 ❌ |
| **cosmic-comp**（COSMIC DE） | ✅ | ❌ | ✅ | ❌ | ✅ | ❌ | ✅ | ❌ | ✅ | bar ✅；**ToplevelManager ❌**（Quickshell 只认 wlr-ftm）；输出捕获 ✅（ICC）；锁屏 ✅；wtype ❌ |
| **KWin**（KDE） | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | bar ✅；其余（列表/捕获/锁屏/wtype）❌（§2） |
| **Mutter**（GNOME） | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | **完全不可用**（无 layer-shell，PanelWindow 无法映射）；截屏走 PipeWire RemoteDesktop（portal 层） |
| **Weston**（参考实现） | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | 不可用；自有 desktop-shell / `weston-screenshooter` |

### 源码依据（每行一条）

- **wlroots**（gitlab.freedesktop.org/wlroots/wlroots，master，`types/`）：
  `wlr_layer_shell_v1.c`、`wlr_foreign_toplevel_management_v1.c`、
  `wlr_ext_foreign_toplevel_list_v1.c`、`wlr_screencopy_v1.c`、
  `ext_image_capture_source_v1/`（目录）、`wlr_ext_image_copy_capture_v1.c`、
  `wlr_session_lock_v1.c`、`wlr_virtual_keyboard_v1.c`、`wlr_data_control_v1.c` +
  `wlr_ext_data_control_v1.c`、`wlr_ext_workspace_v1.c`。
  **注意**：wlroots **无** `ext-foreign-toplevel-image-capture-source` 实现——
  labwc 0.20 的 toplevel capture 是 labwc 自己实现的（`src/server.c`），非 wlroots 助手。
- **Hyprland**（github.com/hyprwm/Hyprland，main，`src/protocols/`）：
  `LayerShell.cpp`、`ForeignToplevelWlr.cpp`（wlr-ftm）、`ForeignToplevel.cpp`（ext-list）、
  `Screencopy.cpp`、`ImageCaptureSource.cpp` + `ImageCopyCapture.cpp`、
  `ToplevelExport.cpp`（TLE）、`SessionLock.cpp`、`VirtualKeyboard.cpp`、
  `DataDeviceWlr.cpp` + `ExtDataDevice.cpp`、`ExtWorkspace.cpp`。
- **niri**（github.com/YaLTeR/niri，main）：`src/handlers/layer_shell.rs` + `src/layer/`、
  `src/protocols/foreign_toplevel.rs`（**同时实现** wlr-ftm 与 ext-list）、
  `src/protocols/screencopy.rs`（wlr-screencopy）、`src/protocols/ext_workspace.rs`、
  `src/protocols/gamma_control.rs`、`src/protocols/output_management.rs`。
  缺：virtual-keyboard、data-control、session-lock、image-capture（全树无对应文件）。
- **cosmic-comp**（github.com/pop-os/cosmic-comp，master，`src/wayland/handlers/`）：
  `layer_shell.rs`、`foreign_toplevel_list.rs`（ext-list）、`toplevel_management.rs`
  （**cosmic 私有** cosmic-toplevel-management，非 wlr-ftm）、`image_capture_source.rs` +
  `image_copy_capture/`、`session_lock.rs`、`data_control/{wlr,ext}.rs`、`workspace.rs`。
  缺：wlr-foreign-toplevel-management、wlr-screencopy、virtual-keyboard。
- **Mutter**（gitlab.gnome.org/GNOME/mutter，main，`src/wayland/`，174 个文件全列比对）：
  无 layer-shell / foreign-toplevel（两版）/ screencopy / ICC / virtual-keyboard /
  session-lock / data-control；有 `meta-wayland-text-input.c`、`meta-wayland-xdg-foreign.c`
  （xdg-foreign-v2）、`meta-wayland-xdg-toplevel-tag.c` 等。
- **Weston**（gitlab.freedesktop.org/wayland/weston，master）：全树 600+ 路径 grep
  layer-shell/foreign-toplevel/screencopy/data-control/virtual-keyboard/image-capture/
  session-lock **零命中**；截图走自有 `frontend/weston-screenshooter.c`。

---

## 4. 直接回答：还有哪些"像 Hyprland 一样"能跑 Quickshell？

1. **严格意义的"桌面环境"里，没有第二个**。KDE（KWin）、GNOME（Mutter）、COSMIC
   （cosmic-comp）都不提供 Quickshell 所需的协议全集——KDE/GNOME 是**拒绝**实现
   （各自有私有窗口管理/截屏体系），COSMIC 是**只实现了 ext 版列表协议**，
   Quickshell 的 ToplevelManager 认 wlr 版。
2. **能像 Hyprland 一样跑 Quickshell 的是一众 wlroots 合成器**（sway、labwc 0.20+、
   wayfire、river、cage 等）和 **niri**——它们不是完整 DE，但 Quickshell 的核心三件套
   （layer-shell bar、wlr-foreign-toplevel 窗口列表、wlr-screencopy/ICC 输出捕获）
   全齐，锁屏/wtype/剪贴板也齐（niri 缺锁屏、wtype、data-control）。
3. **toplevel 缩略图是 Hyprland 独占**（`hyprland-toplevel-export-v1`，Quickshell 唯一
   toplevel 捕获后端）。在 Quickshell #160 落地前，任何非 Hyprland 合成器上
   `ScreencopyView` 都出不了窗口缩略图——labwc 分支已用自写
   `sumika-overview-thumbnaild` daemon + `grim -T` 绕过（见
   [labwc 可行性调查 §2.6](labwc-adaptation-feasibility.md)）。该 daemon 依赖
   `ext-foreign-toplevel-image-capture-source` + `ext-image-copy-capture`，而
   **wlroots 库本身没有 toplevel-image-capture-source 实现**：labwc 0.20+
   是自实现（`src/server.c`），cosmic-comp 也实现了该协议，故方案在
   labwc 0.20+ / cosmic-comp 可移植；**sway/wayfire 等纯 wlroots 合成器默认没有**，
   KWin/Mutter/Weston 也没有（§3 矩阵）。

---

## 附录：参考链接

- Quickshell master 源码 — https://github.com/quickshell-mirror/quickshell
- Quickshell issue #160 — https://github.com/quickshell-mirror/quickshell/issues/160
- KWin master — https://invent.kde.org/plasma/kwin（GitHub 镜像：https://github.com/KDE/kwin）
- KDE Bug 502647（wlr foreign toplevel，RESOLVED/INTENTIONAL）— https://bugs.kde.org/show_bug.cgi?id=502647
- KDE Bug 512996（virtual keyboard，拒绝→libei）— https://bugs.kde.org/show_bug.cgi?id=512996
- wlroots — https://gitlab.freedesktop.org/wlroots/wlroots
- niri — https://github.com/YaLTeR/niri
- cosmic-comp — https://github.com/pop-os/cosmic-comp
- Mutter — https://gitlab.gnome.org/GNOME/mutter
- Weston — https://gitlab.freedesktop.org/wayland/weston
