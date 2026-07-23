# Default Modules

此目录存放 Sumika Shell 的**默认核心模块**。这些模块提供基本桌面功能，与主仓库一起发布。

## 设计原则

| 位置 | 内容 | 优先级 |
|---|---|---|
| `OMD/modules/` | 默认模块（bar 按钮、弹出面板、overlay） | 优先加载，同名模块不覆盖 |
| `$SUMIKA_MODULES_HOME` | 外部模块（第三方、自选覆盖） | 后加载，重复 ID 被默认模块跳过 |

启动脚本先扫 `OMD/modules/` 再扫 `SUMIKA_MODULES_HOME`（默认 `~/development/sumika-modules`）。重复 module ID 的模块，默认模块优先。

## 默认模块清单

| 模块 | 提供 | 依赖服务 |
|---|---|---|
| `active-window` | bar 按钮 (left, alwaysShow) | HyprlandData |
| `app-launcher` | bar 按钮 (left, alwaysShow)、启动器 | — |
| `audio` | bar 按钮 (right, alwaysShow)、弹出面板、设置页 | Audio |
| `clock` | bar 按钮 (right, alwaysShow) | DateTime |
| `display` | bar 按钮 (right)、弹出面板、设置页 | Brightness |
| `input-method` | bar 按钮 (right)、弹出面板 | InputMethod |
| `launcher` | app-launcher 目录/文件工具 | — |
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
