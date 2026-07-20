# QuickShell 精简 Phase 1 删除计划

日期：2026-06-20

目标：在保留当前横向 topbar、Overview、截图、右侧控制中心等核心体验的前提下，删除首批低频模块，降低 QML 扫描量和启动期服务负担。

## 删除前基线

- 基线提交：`ce95e33 baseline: save current quickshell state before slimming`
- 当前配置使用横向 topbar：`bar.vertical: false`
- 翻译关闭：`sidebar.translator.enable: false`
- 壁纸由 dotfiles/脚本管理，不使用内置壁纸选择器

## 本批删除范围

1. `modules/ii/verticalBar/`
   - 原因：当前不使用竖向 bar，横向 `Bar` 已覆盖核心显示。
   - 同步处理：移除 `IllogicalImpulseFamily.qml` 中的 import 和 `VerticalBar` loader。

2. `modules/ii/onScreenKeyboard/`
   - 原因：低频桌面键盘，不作为当前核心功能。
   - 同步处理：移除 `IllogicalImpulseFamily.qml` loader，移除右侧 quick toggles 中的 on-screen keyboard 类型。

3. `modules/ii/screenTranslator/` + `services/GoogleCloud.qml`
   - 原因：屏幕 OCR 翻译已关闭，Google Cloud token 服务不再需要。
   - 同步处理：删除 `modules/common/models/gCloud/`，避免保留只依赖 `GoogleCloud` 的死代码。

4. `modules/ii/wallpaperSelector/` + `services/Wallpapers.qml`
   - 原因：不使用 shell 内置壁纸选择器。
   - 同步处理：移除 `shell.qml` 的 `Wallpapers.load()`，移除 Overview action 中的 wallpaper selector 全局快捷入口，移除 `GlobalStates.wallpaperSelectorOpen`。

## 验证点

- `rg` 不再出现已删除类型的活跃 QML 引用：
  - `VerticalBar`
  - `OnScreenKeyboard`
  - `ScreenTranslator`
  - `WallpaperSelector`
  - `GoogleCloud`
  - `Wallpapers`
- `quickshell -c ii -d` 能加载配置。
- 顶栏、Overview、右侧控制中心、截图/录屏、通知仍能打开。

## 后续候选

- `modules/ii/appLauncher/`：与 Overview 搜索重叠。
- `modules/ii/mediaControls/`：若不使用浮动媒体面板，可删除。
- `modules/ii/overlay/`：功能杂，建议后续拆分或整块移除。
- `modules/ii/schedulePopup/`：如不用日历/待办/番茄钟，可删除。
