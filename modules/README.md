# Modules

Sumika Shell 使用**单一外部模块仓库**放置所有功能模块。`OMD/modules/` 不再包含功能模块，仅保留此说明文件。

## 模块位置

| 位置 | 内容 |
|---|---|
| `$SUMIKA_MODULES_HOME` (默认 `~/development/sumika-modules/`) | 所有功能模块（27 个）：包括 product-floor 最小桌面模块 + 可选模块 |
| `OMD/quickshell/modules/` | 共享 QML 导入库（7 个）：`bar`、`common`、`settings`、`overview`、`onScreenDisplay`、`notificationPopup`、`polkit` |

启动脚本扫描 `$SUMIKA_MODULES_HOME/*/module.json` 生成注册表，并将 QML import path 指向模块目录。

## 最小桌面（product floor）

下列模块是**产品最小桌面**，`modules.enabled = false` 或列入 `modules.disabled` 时仍保持启用：

| 模块 ID | 角色 |
|---|---|
| `launcher` | 应用启动器（on-demand 进程） |
| `clock` | 时钟 |
| `notification-popup` | 通知弹出窗口 |
| `workspaces` | 工作区指示 |
| `overview` | 工作区概览（常驻 application 进程） |
| `systray` | 系统托盘 |
| `wifi` | 网络 |
| `audio` | 音量 |
| `power-indicator` | 电源/状态指示 |
| `display` | 显示设置 |

配置（`sumika.json` / Config）：

```json
"modules": {
  "enabled": true,
  "disabled": [],
  "required": ["launcher", "clock", "notification-popup", "workspaces", "overview", "systray", "wifi", "audio", "power-indicator", "display"]
}
```

- `enabled`：可选模块总开关（关 = 只留最小桌面）
- `disabled`：仅对非 required 模块生效
- `required`：可**追加**更多必装 ID；硬编码 floor 始终并入，无法通过配置缩减

所有功能模块统一放在 **`$SUMIKA_MODULES_HOME`**。外部模块也在此处，无优先级区分。
