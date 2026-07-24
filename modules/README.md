# Default Modules

此目录存放 Sumika Shell 的**默认核心模块**。这些模块提供基本桌面功能，与主仓库一起发布。

## 设计原则

| 位置 | 内容 | 优先级 |
|---|---|---|
| `OMD/modules/` | 默认模块（bar 按钮、弹出面板、overlay） | 优先加载，同名模块不覆盖 |
| `$SUMIKA_MODULES_HOME` | 外部模块（第三方、自选覆盖） | 后加载，重复 ID 被默认模块跳过 |

启动脚本先扫 `OMD/modules/` 再扫 `SUMIKA_MODULES_HOME`（默认 `~/development/sumika-modules`）。重复 module ID 的模块，默认模块优先。

## 最小桌面（product floor）

下列模块是 **产品最小桌面**，不能比这更小。`modules.enabled = false` 或列入 `modules.disabled` 时，它们仍保持启用：

| 模块 ID | 角色 |
|---|---|
| `launcher` | 应用启动器（内置：`OMD/modules/launcher`，on-demand 进程） |
| `workspaces` | 工作区指示 |
| `clock` | 时钟 |
| `systray` | 系统托盘 |
| `wifi` | 网络 |
| `audio` | 音量 |
| `power-indicator` | 电源/状态指示 |

配置（`sumika.json` / Config）：

```json
"modules": {
  "enabled": true,
  "disabled": [],
  "required": ["launcher", "clock", "workspaces", "systray", "wifi", "audio", "power-indicator"]
}
```

- `enabled`：可选模块总开关（关 = 只留最小桌面）
- `disabled`：仅对非 required 模块生效
- `required`：可 **追加** 更多必装 ID；硬编码 floor 始终并入，无法通过配置缩减

内置默认模块只放在 **`OMD/modules/`**；`$SUMIKA_MODULES_HOME` 仅用于外置/第三方模块。

## 默认模块清单

| 模块 | 提供 | 依赖服务 |
|---|---|---|
| `active-window` | bar 按钮 (left, alwaysShow) | HyprlandData |
| `audio` | bar 按钮 (right, alwaysShow)、弹出面板、设置页 | Audio |
| `clock` | bar 按钮 (right, alwaysShow) | DateTime |
| `display` | bar 按钮 (right)、弹出面板、设置页 | Brightness |
| `input-method` | bar 按钮 (right)、弹出面板 | InputMethod |
| `launcher` | bar 按钮 (left) + on-demand 启动器 UI（`shell.qml`） | — |
| `notification` | 设置页、弹出面板 | Notifications |
| `notification-popup` | overlay（通知弹出窗口） | — |
| `on-screen-display` | overlay（OSD 指示器） | — |
| `overview` | 工作区概览框架注册 | — |
| `session` | bar 按钮 (right) | — |
| `power-indicator` | bar 按钮 (right, alwaysShow) | Audio, Network, Battery, MprisController |
| `wifi` | bar 按钮 (right, alwaysShow)、弹出面板、设置页 | Network |
| `workspaces` | bar 按钮 (left) | — |

## 迁移状态

这些模块原本在 `OMD/modules/` 中开发，中间经过一轮提取到独立 `sumika-modules` 仓库，现已作为默认模块移回主仓库。
