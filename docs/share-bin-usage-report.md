# share/bin/omarchy-* 脚本使用情况审计

> 调查日期：2026-07-24
> 范围：`~/development/OMD/share/bin/`（42 个 `omarchy-*` 脚本）

## 摘要

42 个 `omarchy-*` 脚本中，**12 个被实际使用**，**30+ 个虽然实现完整但未被运行时调用**（因为 39 个 `bin/omd-*` shim 因模板变量 `$target` 未定义全部不可运行）。

---

## 已使用的脚本（12 个）

### 1. 语音输入法 — 4 个脚本，核心依赖

| 脚本 | 被调用位置 | 说明 |
|---|---|---|
| `omarchy-voice-setup` | `bin/omd-voice-setup`（正确 shim）、`sumika-modules/voice/bin/omd-settings-voice` | 安装语音依赖环境（Python venv、SenseVoice ONNX 模型） |
| `omarchy-voice-download` | `bin/omd-voice-download`（正确 shim）、`sumika-modules/voice/bin/omd-settings-voice` | 下载 SenseVoice 模型到本地缓存 |
| `omarchy-voice-record` | `sumika-modules/voice/bin/omd-settings-voice` 行 648、668 | 录制麦克风输入到 `/tmp/omd-voice-rec.wav` |
| `omarchy-voice-transcribe` | `bin/omd-voice-transcribe`（正确 shim）、`sumika-modules/voice/bin/omd-settings-voice` 行 580、659 | 基于 SenseVoice AI 的离线转写 |

**用户问的「我们自己的语音输入法」就是这套。**

### 2. 系统锁/登出/唤醒 — 3 个脚本，shim 正确

| 脚本 | `bin/` shim | 调用方 |
|---|---|---|
| `omarchy-system-lock` | `bin/omd-lock` ✓ | `hypridle.conf`（超时锁屏行 2-3、15-16）、Hyprland 键绑定 |
| `omarchy-system-logout` | `bin/omd-logout` ✓ | `core/runtime/ActionManager.qml`（菜单行 234、259）、`modules/session/services/Session.qml`、`quickshell/modules/common/functions/Session.qml` |
| `omarchy-system-wake` | `bin/omd-wake` ✓ | `hypridle.conf` after_sleep_cmd（行 4） |

### 3. 键盘映射 — 3 个脚本，直接调用（不经过 OMD `bin/` shim）

| 脚本 | 调用方 |
|---|---|
| `omarchy-keyboard-render` | `sumika-modules/keyboard-remap/bin/omd-settings-keyboard` 行 24 |
| `omarchy-keyboard-setup` | `sumika-modules/keyboard-remap/bin/omd-settings-keyboard` 行 34 |
| `omarchy-keyboard-apply` | `sumika-modules/keyboard-remap/bin/omd-settings-keyboard` 行 38 |

路径写死为 `"${OMD_ROOT}/share/bin/omarchy-keyboard-*"`，不经过碎 shim。

### 4. 贴到光标 — 1 个脚本，但 shim 断裂

| 脚本 | 调用方 |
|---|---|
| `omarchy-paste-at-cursor` | `bin/omd-kitty-smart-paste` 行 62、`sumika-modules/voice/VoicePopup.qml` 行 181、`quickshell/services/VoiceInput.qml` 行 39、`services/VoiceInput.qml` 行 38 |

**断裂原因**：`bin/omd-paste-at-cursor` 内容为：
```sh
exec "$(dirname "$0")/../share/bin/'"$target"'" "$@"
```
`$target` 模板变量从未赋值 → 运行时报错。语音转写的自动粘贴链因此中断。

---

## 未使用的脚本（30+ 个）

### 共同断裂原因

39 个 `bin/omd-*` 脚本内容完全相同：
```sh
#!/bin/sh
exec "$(dirname "$0")/../share/bin/'"$target"'" "$@"
```
**`$target` 变量从未定义**。这些 shim 全部不可运行。

| 分类 | 脚本 | 预期的调用方 | 实际效果 |
|---|---|---|---|
| **亮度** | `omd-brightness-display`、`omd-brightness-keyboard` | `hypr/default/hypr/bindings/media.lua` XF86MonBrightness* 键绑定 | 按亮度键无反应 |
| **音频** | `omd-audio-input-mute`、`omd-audio-output-switch` | `media.lua` XF86Audio* 键绑定 | 按静音/切换键无反应 |
| **窗口管理**（6 个） | `omd-hyprland-window-close-all`、`omd-hyprland-window-pop`、`omd-hyprland-window-transparency-toggle`、`omd-hyprland-window-gaps-toggle`、`omd-hyprland-window-single-square-aspect-toggle`、`omd-hyprland-workspace-layout-toggle` | Hyprland 键绑定 | 所有窗口管理快捷键无效 |
| **显示器**（4 个） | `omd-hyprland-monitor-scaling-cycle`、`omd-hyprland-monitor-internal`、`omd-hyprland-monitor-internal-mirror`、`omd-hyprland-monitor-watch`、`omd-hw-external-monitors` | Hyprland 键绑定 / 脚本 | 显示器操作快捷键无效 |
| **启动器**（6+ 个） | `omd-launch-browser`、`omd-launch-editor`、`omd-launch-terminal`、`omd-launch-terminal-tmux`、`omd-launch-tui`、`omd-launch-webapp`、`omd-launch-or-focus`、`omd-launch-or-focus-tui`、`omd-launch-or-focus-webapp` | Hyprland 键绑定 / 启动器配置 | 快捷键启动浏览器/终端等无效 |
| **其他** | `omd-toggle-touchpad`、`omd-powerprofiles-init`、`omd-keyboard-*`（4 个 shim 版本） | Hyprland 键绑定 / 系统服务 | 触摸板切换快捷键无效 |

**注意**：`omd-keyboard-*` 的 shim 虽然碎了，但功能不受影响——`sumika-modules/keyboard-remap/` 直接调用 `$OMD_ROOT/share/bin/omarchy-keyboard-*`，绕过了 shim。

### 间接影响

锁屏脚本 `omarchy-system-lock`（行 21-22）和唤醒脚本 `omarchy-system-wake`（行 5-6）内部调用了碎 shim：

```sh
# omarchy-system-lock
omd-brightness-keyboard off
omd-brightness-display off

# omarchy-system-wake
omd-brightness-display on
omd-brightness-keyboard restore
```

因此锁屏后键盘背光和显示器亮度不会关闭，唤醒后也不会恢复。这是独立于键绑定之外的另一个影响点。

---

## 架构图

```
share/bin/omarchy-* (42 个脚本)
│
├── 实际使用 (12)
│   ├── voice-{setup,download,record,transcribe} (4)
│   │   └── 自家语音输入法，端到端工作
│   ├── system-{lock,logout,wake} (3)
│   │   ├── shim (omd-lock/logout/wake) 正确
│   │   └── 锁屏内还调用碎 shim → 不关灯
│   ├── keyboard-{render,setup,apply} (3)
│   │   └── 直接调用，不经过 shim
│   └── paste-at-cursor (1)
│       └── shim (omd-paste-at-cursor) 碎了 → 语音粘贴断链
│
├── 实现完整但 shim 断裂 (30+)
│   ├── brightness-*, audio-*        → 键绑定无效
│   ├── launch-*                     → 启动器快捷键无效
│   ├── hyprland-window-*            → 窗口管理快捷键无效
│   ├── hyprland-monitor-*           → 显示器操作无效
│   └── toggle-touchpad 等           → 其他快捷键无效
│
└── 未使用且无 shim
    └── omarchy-system-suspend 等（无 bin/omd-* 入口）
```

## 根因

39 个 `bin/omd-*` shim 文件看起来像模板文件未被正确生成/展开。它们本应指向对应 `share/bin/omarchy-*` 的真实路径（如同 `bin/omd-lock/logout/wake` 和 `bin/omd-voice-*` 那样硬编码路径），但实际内容使用了未定义的 `$target` 变量。

## 修复方向

修复方案无非两种：

1. **修复 shim**：将 39 个文件逐一改为类似 `bin/omd-lock` 的硬编码形式 —— 直接 `exec share/bin/omarchy-<name> "$@"`。
2. **绕开 shim**：将 Hyprland 键绑定等调用点直接改为 `share/bin/omarchy-*` 路径。
