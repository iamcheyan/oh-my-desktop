# OMD 仓库检查报告

> 日期：2026-07-20
> 仓库：~/development/OMD
> 分支：main

## 编译状态

| 进程 | 状态 |
|---|---|
| omd-bar | ✅ Configuration Loaded |
| omd-overview | ✅ Configuration Loaded |
| omd-applauncher | ✅ Configuration Loaded |
| omd-clipboard | ✅ Configuration Loaded |

## Git 状态

工作区干净，无未提交改动。

## 模块系统基础设施

| 组件 | 文件 | 状态 |
|---|---|---|
| ModuleLoader 单例 | services/ModuleLoader.qml | ✅ 通过 Process 读注册表 |
| qs 模块声明 | quickshell/qmldir | ✅ `module qs` |
| services qmldir | services/qmldir | ✅ 30 个 singleton 声明 |
| common qmldir | modules/common/qmldir | ✅ 5 个 singleton |
| common/widgets qmldir | modules/common/widgets/qmldir | ✅ 1 个 singleton |
| common/functions qmldir | modules/common/functions/qmldir | ✅ 9 个 singleton |
| 启动脚本模块扫描 | scripts/quickshell | ✅ jq + file:// 修复 |
| Config modules 字段 | Config.qml + config.json | ✅ disabled + barButtonOrder |
| BarStatusPopup Repeater | BarStatusPopup.qml:244-257 | ✅ 动态加载模块弹窗 |
| SettingsDialog 模块支持 | SettingsDialog.qml:51-56, 106-111 | ✅ 动态加载模块设置页 |

## 恢复的文件（从 git 历史）

| 文件 | 原因 |
|---|---|
| BarContent.qml | 从 commit 65c3637 恢复（10 个按钮） |
| BarStatusPopup.qml | 从 commit 65c3637 恢复（2811 行，13 个 section） |
| bar/modules/ClipboardButton.qml | 被模块拆分删除 |
| bar/modules/DisplayButton.qml | 被模块拆分删除 |
| bar/modules/SessionButton.qml | 被模块拆分删除 |
| bar/modules/ScreenshotContextMenu.qml | 被模块拆分删除 |
| settings/pages/VoicePage.qml | 被模块拆分删除 |
| settings/pages/WindowsVmPage.qml | 被模块拆分删除 |
| settings/pages/KeyboardRemapPage.qml | 被模块拆分删除 |
| settings/pages/KeyboardEditorOverlay.qml | 被模块拆分删除 |
| settings/pages/PowerPage.qml | 被模块拆分删除 |
| settings/display/ (7 files) | 被模块拆分删除 |
| services/FirstRunExperience.qml | 被 commit bb84cd9 误删 |
| services/ConflictKiller.qml | 被 commit bb84cd9 误删 |
| services/Updates.qml | 被 commit bb84cd9 误删 |
| bin/omd-backup 等 7 个脚本 | 被模块拆分删除 |

## qmldir 文件清单

| 路径 | 模块名 | 内容 |
|---|---|---|
| quickshell/qmldir | qs | 仅 module 声明 |
| services/qmldir | qs.services | 30 个 singleton |
| modules/common/qmldir | qs.modules.common | 5 个 singleton + 2 个组件 |
| modules/common/widgets/qmldir | qs.modules.common.widgets | 1 个 singleton + 组件 |
| modules/common/functions/qmldir | qs.modules.common.functions | 9 个 singleton |
| modules/settings/qmldir | qs.modules.settings | 3 个组件 |
| modules/settings/pages/qmldir | qs.modules.settings.pages | 11 个页面 |
| modules/settings/widgets/qmldir | qs.modules.settings.widgets | 22 个组件 |
| modules/settings/wallpaper/qmldir | qs.modules.settings.wallpaper | 组件 |

## 7 个问题最终状态

| # | 问题 | 状态 |
|---|---|---|
| 1 | inline component 依赖 | ✅ popup-components 共享模块 |
| 2 | bar qmldir 循环依赖 | ✅ 绕过 |
| 3 | 服务文件重复 | ✅ 模块副本已删，用核心 singleton |
| 4 | bin 脚本重复 | ✅ 模块副本已删，核心保留 |
| 5 | bin 脚本从核心删除 | ✅ 7 个恢复到核心 |
| 6 | module.json 格式 | ✅ 修复 |
| 7 | qmldir 手动维护 | ✅ generate-qmldir.sh |

## 工具脚本

| 脚本 | 用途 |
|---|---|
| scripts/generate-qmldir.sh | 自动生成 qmldir（含 singleton 声明） |

## 已知限制

1. **BarContent 无 Repeater**：bar 按钮全部在核心，模块不提供 bar 按钮。待按钮迁移到模块后添加。
2. **模块弹窗与核心弹窗并存**：BarStatusPopup 同时有 contentLoader（核心）和 Repeater（模块）。对于相同 type（如 battery），两者都加载，核心在上层可见。后续需移除核心弹窗让模块接管。
3. **部分模块无功能**：brightness-gamma、mpris、systray、clipboard、screenshot 只有 module.json 和 qmldir，没有 popup/settings/bar 文件。这些模块的功能仍在核心。
4. **运行时未测试**：模块弹窗能否通过 Repeater 成功加载尚未在运行时验证（需 omd-restart 后手动测试）。