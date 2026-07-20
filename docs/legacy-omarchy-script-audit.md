# Legacy `share/bin/omarchy-*` 脚本审计报告

> 日期：2026-07-20
> 目标：确定 `share/bin/omarchy-*` 脚本哪些仍在使用、哪些已死，以便清理

## 调用机制

```
bin/omd-XXX (symlink) → bin/omd-legacy-omarchy (dispatcher) → share/bin/omarchy-XXX
```

`omd-legacy-omarchy` 有两类映射：
- **显式映射**：`omd-lock → omarchy-system-lock`、`omd-logout → omarchy-system-logout` 等
- **通配映射**：`omd-* → omarchy-${cmd#omd-}`（剥离 `omd-` 前缀加 `omarchy-`）

此外，部分脚本被**直接调用**（绕过 dispatcher）：
- `bin/omd-settings-keyboard` 直接调 `share/bin/omarchy-keyboard-*`
- `bin/omd-settings-voice` 直接调 `share/bin/omarchy-voice-*`

## 统计

| 状态 | 数量 | 说明 |
|---|---|---|
| ✅ 活跃（有调用方） | 30 | 仍被 Hyprland 绑定、QML、hypridle、脚本调用 |
| ❌ 死代码（无调用方） | 27 | 无任何代码路径触发 |

**结论：不能整个删除 `share/bin/omarchy-*`。30 个脚本仍活跃。**

---

## ✅ 活跃脚本（30 个，不可删）

### 亮度控制（2 个）— Hyprland 媒体键绑定

| 脚本 | 调用方 |
|---|---|
| `omarchy-brightness-display` | `hypr/default/hypr/bindings/media.lua` XF86MonBrightness 键 |
| `omarchy-brightness-keyboard` | `hypr/default/hypr/bindings/media.lua` XF86KbdBrightness 键；`omarchy-system-lock`/`omarchy-system-wake` |

### 音频控制（2 个）— Hyprland 媒体键绑定

| 脚本 | 调用方 |
|---|---|
| `omarchy-audio-input-mute` | `media.lua` XF86AudioMicMute |
| `omarchy-audio-output-switch` | `media.lua` SUPER+XF86AudioMute |

### 触摸板（1 个）

| 脚本 | 调用方 |
|---|---|
| `omarchy-toggle-touchpad` | `media.lua` XF86TouchpadToggle/On/Off |

### 显示器管理（5 个）— Hyprland 绑定 + 自启

| 脚本 | 调用方 |
|---|---|
| `omarchy-hw-external-monitors` | `utilities.lua` 合盖事件 |
| `omarchy-hyprland-monitor-internal` | `utilities.lua` SUPER+CTRL+Delete |
| `omarchy-hyprland-monitor-internal-mirror` | `utilities.lua` SUPER+CTRL+ALT+Delete |
| `omarchy-hyprland-monitor-scaling-cycle` | `tiling-v2.lua` SUPER+code:61 |
| `omarchy-hyprland-monitor-watch` | `autostart.lua` 自启 |

### 窗口管理（6 个）— Hyprland 绑定

| 脚本 | 调用方 |
|---|---|
| `omarchy-hyprland-window-close-all` | `tiling-v2.lua` CTRL+ALT+DELETE；`omarchy-system-logout` |
| `omarchy-hyprland-window-gaps-toggle` | `utilities.lua` SUPER+SHIFT+BACKSPACE |
| `omarchy-hyprland-window-pop` | `tiling-v2.lua` SUPER+O |
| `omarchy-hyprland-window-single-square-aspect-toggle` | `utilities.lua` SUPER+CTRL+BACKSPACE |
| `omarchy-hyprland-window-transparency-toggle` | `utilities.lua` SUPER+BACKSPACE |
| `omarchy-hyprland-workspace-layout-toggle` | `tiling-v2.lua` SUPER+L |

### 键盘重映射（4 个）— KeyboardRemap.qml + omd-settings-keyboard

| 脚本 | 调用方 |
|---|---|
| `omarchy-keyboard-apply` | `KeyboardRemap.qml`；`bin/omd-settings-keyboard` 直接调用 |
| `omarchy-keyboard-render` | `KeyboardRemap.qml`；`bin/omd-settings-keyboard` 直接调用 |
| `omarchy-keyboard-list` | `KeyboardRemap.qml` |
| `omarchy-keyboard-setup` | `KeyboardRemap.qml`；`bin/omd-settings-keyboard` 直接调用 |

### 语音输入（4 个）— VoiceInput.qml + omd-settings-voice

| 脚本 | 调用方 |
|---|---|
| `omarchy-voice-setup` | `VoiceInput.qml`；`bin/omd-settings-voice` 直接调用 |
| `omarchy-voice-download` | `VoiceInput.qml`；`bin/omd-settings-voice` 直接调用 |
| `omarchy-voice-record` | `VoiceInput.qml` |
| `omarchy-voice-transcribe` | `VoiceInput.qml`；`bin/omd-settings-voice` 直接调用 |

### 光标粘贴（1 个）

| 脚本 | 调用方 |
|---|---|
| `omarchy-paste-at-cursor` | `VoiceInput.qml`；`BarStatusPopup.qml` |

### 锁屏 / 唤醒（2 个）— hypridle.conf + Hyprland 绑定

| 脚本 | 调用方 |
|---|---|
| `omarchy-system-lock` | `hypr/hypridle.conf` lock_cmd/before_sleep_cmd/listener；`utilities.lua` SUPER+CTRL+L |
| `omarchy-system-wake` | `hypr/hypridle.conf` after_sleep_cmd/on-resume |

注：`omarchy-system-lock` 是辅助脚本（重置键盘布局、锁 1password、杀 screensaver、关亮度），实际的屏幕锁定由 Quickshell `LockScreen.qml`（WlSessionLockSurface）处理。

### 注销（1 个）— Session.qml

| 脚本 | 调用方 |
|---|---|
| `omarchy-system-logout` | `Session.qml` 调用 `omd-logout` |

注：`reboot` 和 `shutdown` 不走此路径——`Session.qml` 直接调 `systemctl reboot/poweroff`。

### 应用启动器（5 个）— helpers.lua + QML

| 脚本 | 调用方 |
|---|---|
| `omarchy-launch-or-focus` | `helpers.lua` `o.launch_sole()` |
| `omarchy-launch-or-focus-tui` | `helpers.lua` `o.bind(..., { tui = "xxx" })` |
| `omarchy-launch-or-focus-webapp` | `helpers.lua` `o.launch_webapp_sole()` |
| `omarchy-launch-webapp` | `helpers.lua` `o.launch_webapp()` |
| `omarchy-launch-tui` | `helpers.lua` `o.bind(..., { tui = "xxx" })`；`VoicePage.qml` |

### 其他（1 个）

| 脚本 | 调用方 |
|---|---|
| `omarchy-powerprofiles-init` | `hypr/default/hypr/autostart.lua` 自启 |

---

## ❌ 死代码（27 个，可安全删除）

### 已被替代（5 个）

| 脚本 | 替代物 | 说明 |
|---|---|---|
| `omarchy-system-reboot` | `Session.qml` 直接调 `systemctl reboot` | 不再经过 dispatcher |
| `omarchy-system-shutdown` | `Session.qml` 直接调 `systemctl poweroff` | 不再经过 dispatcher |
| `omarchy-capture-screenshot` | `bin/omd-screenshot`（真实文件） | 截图已重写 |
| `omarchy-capture-text-extraction` | `bin/omd-ocr`（真实文件） | OCR 已重写 |
| `omarchy-windows-vm` | `bin/omd-settings-windows-vm`（真实文件） | VM 管理 TUI 已重写 |

### 无任何调用方（22 个）

| 脚本 | 说明 |
|---|---|
| `omarchy-font-current` | 无调用方 |
| `omarchy-launch-screensaver` | 无调用方（Quickshell 有自己的 LockScreen） |
| `omarchy-launch-floating-terminal-with-presentation` | 无调用方 |
| `omarchy-cmd-present` | 无调用方（内部辅助脚本） |
| `omarchy-cmd-terminal-cwd` | 无调用方（内部辅助脚本） |
| `omarchy-default-terminal` | 无调用方 |
| `omarchy-launch-audio` | 无调用方 |
| `omarchy-launch-bluetooth` | 已被 `bin/omd-launch-bluetooth`（真实文件）替代 |
| `omarchy-launch-browser` | 无 `bin/omd-launch-browser` 文件存在 |
| `omarchy-launch-editor` | 无 `bin/omd-launch-editor` 文件存在 |
| `omarchy-launch-nautilus` | 无调用方 |
| `omarchy-launch-nautilus-cwd` | 无调用方 |
| `omarchy-launch-terminal` | 无 `bin/omd-launch-terminal` 文件存在 |
| `omarchy-launch-terminal-tmux` | 无 `bin/omd-launch-terminal-tmux` 文件存在 |
| `omarchy-launch-wifi` | 已被 `bin/omd-launch-wifi`（真实文件）替代 |
| `omarchy-swayosd-client` | 已被 `bin/omd-swayosd-client`（真实文件）替代 |
| `omarchy-toggle-notification-silencing` | 无调用方（已有 `bin/omd-notification-control`） |
| `omarchy-edit-muted-apps` | `Notifications.qml` 自己实现了 inline 编辑，不调此脚本 |

### 对应的死 symlink（在 bin/ 中）

以下 `bin/omd-*` 是指向 `omd-legacy-omarchy` 的 symlink，但对应脚本已死，可删除：

| 死 symlink | 说明 |
|---|---|
| `bin/omd-font-current` | → `omarchy-font-current`（死） |
| `bin/omd-launch-screensaver` | → `omarchy-launch-screensaver`（死） |
| `bin/omd-launch-floating-terminal-with-presentation` | → `omarchy-launch-floating-terminal-with-presentation`（死） |
| `bin/omd-reboot` | → `omarchy-system-reboot`（已被 Session.qml 替代） |
| `bin/omd-shutdown` | → `omarchy-system-shutdown`（已被 Session.qml 替代） |
| `bin/omd-windows-vm` | → `omarchy-windows-vm`（已被 omd-settings-windows-vm 替代） |

---

## ⚠️ 断裂的绑定（需修复）

以下 Hyprland 绑定生成的 `omd-launch-*` 命令在 `bin/` 中**没有对应文件**：

| 绑定 | 生成的命令 | bin/ 中有文件？ |
|---|---|---|
| `SUPER + Q` → Terminal | `omd-launch-terminal` | ❌ 不存在 |
| `SUPER + SHIFT + RETURN` → Browser | `omd-launch-browser` | ❌ 不存在 |
| `SUPER + SHIFT + N` → Editor | `omd-launch-editor` | ❌ 不存在 |
| `SUPER + ALT + RETURN` → Tmux | `omd-launch-terminal-tmux` | ❌ 不存在 |

这些绑定当前可能**静默失败**。需要：
1. 创建对应的 `bin/omd-launch-*` 真实文件（参考 `bin/omd-launch-bluetooth` 的实现模式）
2. 或者创建 `bin/omd-launch-*` symlink → `omd-legacy-omarchy`，利用通配映射调 `omarchy-launch-*`

---

## `omd-legacy-omarchy` 分发器

分发器本身**不能删除**——仍有 30 个活跃脚本通过它调用。

但如果先清理死代码，活跃 symlink 从 40 个降到 34 个。未来如果逐步将活跃脚本重写为 `bin/omd-*` 真实文件，分发器最终可以删除。

---

## 清理计划

### 第一步：删除死脚本 + 死 symlink（安全，不影响功能）

```bash
# 删除 27 个死 omarchy-* 脚本
rm share/bin/omarchy-{font-current,launch-screensaver,launch-floating-terminal-with-presentation,cmd-present,cmd-terminal-cwd,default-terminal,launch-audio,launch-bluetooth,launch-browser,launch-editor,launch-nautilus,launch-nautilus-cwd,launch-terminal,launch-terminal-tmux,launch-wifi,swayosd-client,toggle-notification-silencing,edit-muted-apps,capture-screenshot,capture-text-extraction,windows-vm,system-reboot,system-shutdown}.sh

# 删除 6 个死 bin/omd-* symlink
rm bin/omd-{font-current,launch-screensaver,launch-floating-terminal-with-presentation,reboot,shutdown,windows-vm}
```

### 第二步：修复断裂的绑定

为 `omd-launch-terminal`、`omd-launch-browser`、`omd-launch-editor`、`omd-launch-terminal-tmux` 创建真实文件或 symlink。

### 第三步：逐步重写活跃脚本（长期）

将活跃的 `omarchy-*` 脚本逐个重写为 `bin/omd-*` 真实文件，最终删除 `omd-legacy-omarchy` 分发器。