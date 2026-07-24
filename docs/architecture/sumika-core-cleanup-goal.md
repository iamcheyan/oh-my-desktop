# Sumika Core 全量修复目标

## 最终状态

**一个仓库，不依赖第二个目录。所有启动入口要么工作要么被删除。启动日志零 error。**

## 核心修改原则

1. 不建 symlink staging 目录 — QML import path 直接指向真实文件路径
2. core 仓库内所有模块直接用 `quickshell/modules/<id>/` 真实路径，不通过 staging
3. 删除 `$SUMIKA_MODULES_HOME` — 不再定义、不再导出、不再回退；已有功能全部迁入或删除
4. 所有指向已删除外部模块的 QML Service 彻底移除

---

## Phase A — P0：可安装、可诊断

### A1 修复 Init.sh
- 文件：`Init.sh:1388-1405`
- 补全 `elif` 分支缺失的 `fi`
- 删除 `sumika-modules` clone 提示
- 验收：`bash -n Init.sh` 通过；两次运行均成功且幂等

### A2 修复 omd-doctor
- 文件：`bin/omd-doctor:5`
- `source "$repo/scripts/omd-path.sh"` → `source "$repo/lib/paths.sh"`
- 删除指向已删除模块的硬编码检查
- 验收：`bin/omd-doctor` 完整执行无 shell 异常

### A3 删除 lib/paths.sh 中的 SUMIKA_MODULES_HOME
- 文件：`lib/paths.sh:61`
- 删除 `SUMIKA_MODULES_HOME="${SUMIKA_MODULES_HOME:-$HOME/development/sumika-modules}"`
- 删除对应的 export
- 验收：`env | grep SUMIKA_MODULES_HOME` 无输出

---

## Phase B — QML 报错清零

### B1 Wifi popup：SettingsButton → 原生按钮
- 文件：`quickshell/modules/wifi/WifiPopup.qml`
- 第 343 行 `SettingsButton { ... label: "Connect" ... }` — 替换为 `Rectangle { }` + `StyledText` + `MouseArea` 原生样式，保留连接逻辑
- 第 354 行 `SettingsButton { ... label: "Cancel" ... }` — 同上
- 验收：打开 Wifi popup 不报 `SettingsButton is not a type`

### B2 Display popup：SettingsButton 残留
- 文件：`quickshell/modules/display/popup/DisplayPopup.qml`
- 第 91 行 `SettingsButton` 引用 — 已删除（确认）
- 验收：打开 Display popup 不报 `SettingsButton is not a type`

### B3 确认 TrackArt 在 core 中可用
- `TrackArt.qml` 在 `quickshell/services/` 中已注册为 singleton
- 当外部模块不再被加载时，core `AudioPopup.qml` 的 `TrackArt` import 自动正常
- 验收：Audio popup 打开不报 `TrackArt is not defined`

---

## Phase C — 删除 staging + 所有 SUMIKA_MODULES_HOME 引用

### C1 quickshell/scripts/quickshell 启动脚本
- 删除行 59 的 `ln -sfn "$repo_root/quickshell" "$qml_import_root/qs"` staging symlink
- 改为直接 `export QML_IMPORT_PATH="$repo_root/quickshell${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}"`
- 删除行 66-79 的外部模块 staging 循环
- 删除 `prepare_popup_components_alias()` 函数（行 86-98）
- 删除 `stage_external_module()` 函数（行 100+）
- 删除行 250-254 的第二轮 `SUMIKA_MODULES_HOME` 扫描
- 验收：启动后 registry 只包含 core 模块，无 staging 目录

### C2 quickshell/modules/settings/bin/omd-settings
- 删除 `launch_direct()` 中的 staging 逻辑（行 59-66）
- 删除行 108-123 的 SUMIKA_MODULES_HOME 路由（voice、keyboard、windows-vm）
- QML import path 改为直接指向 `$repo_root/quickshell`
- 验收：`omd-settings open display` 正常运行

### C3 bin/omd-settings（顶层调度器）
- 文件：`bin/omd-settings`
- 删除行 11-16 的 `SUMIKA_MODULES_HOME` 优先检查
- 改为只检查 `quickshell/modules/settings/` 和 `apps/omd-settings/`
- 验收：`bin/omd-settings open display` 工作，日志无 warn

### C4 Settings pages QML 路径修复
- `quickshell/modules/settings/pages/AppearancePage.qml:118,738,764`
- `quickshell/modules/settings/pages/OverviewPage.qml:25,33`
- 所有 `$SUMIKA_MODULES_HOME/settings/bin/...` → `$SUMIKA_SHELL_ROOT/quickshell/modules/settings/bin/...`
- 验收：打开 Appearance/Overview 页面无文件未找到错误

### C5 QML Services — 删除不可用 Service
以下 service 引用的外部模块已不存在，整体删除文件 + qmldir 条目：

| 文件 | 原因 |
|---|---|
| `quickshell/services/VoiceInput.qml` | 依赖 `voice/bin/` |
| `quickshell/services/KeyboardRemap.qml` | 依赖 `keyboard-remap/bin/` |
| `quickshell/services/InputMethod.qml` | 依赖 `input-method/bin/` |

且更新 `quickshell/services/qmldir` 删除对应的 singleton 声明。
验收：Services 目录只包含最小桌面需要的 service

### C6 QML module-actions.qml 路径修复
- `quickshell/modules/launcher/module-actions.qml:9` — SUMIKA_MODULES_HOME → 走 core 路径
- `quickshell/modules/wifi/module-actions.qml:12` — 同上
- `quickshell/modules/common/functions/Session.qml:10` — 删除 autoSavePrefix 中的外部 session 引用（或走 core 路径）
- `quickshell/modules/launcher/modules/appLauncher/AppLauncher.qml:30` — SUMIKA_MODULES_HOME → core `bin/omd-applauncher-cache`
- `quickshell/services/BluetoothStatus.qml:16` — SUMIKA_MODULES_HOME → core `quickshell/modules/wifi/bin`
- 验收：所有引用外部模块的路径都改为 core 路径

### C7 CLI 工具消毒
- `bin/omd-modules` — 重写为只扫描 `quickshell/modules/*/module.json`；删除 clone/update/install
- `bin/omd-module-validate` — 删除 `~development/sumika-modules` fallback
- 验收：`omd-modules list` 只列出 core 模块

---

## Phase D — Wifi/BT TUI 入口

### D1 Wifi popup "Add new Wi-Fi…" 路径净化
- 文件：`quickshell/modules/wifi/WifiPopup.qml:389`
- 当前硬编码 `Quickshell.env("OMD_REPO_ROOT")`，改为 `FileUtils.trimFileProtocol(Directories.root)`
- 验收：点击后启动 `omd-launch-wifi` TUI

### D2 Bluetooth section 底部加 TUI 入口
- 文件：`quickshell/modules/wifi/WifiPopup.qml` — 蓝牙 device 列表区域
- 在蓝牙设备列表尾部加 "Bluetooth settings…" 按钮，启动 `omd-launch-bluetooth`
- 验收：Bluetooth TUI 入口可见且可点击

---

## Phase E — 文档更新

### E1 AGENTS.md
- 删除所有 `$SUMIKA_MODULES_HOME` 和两仓库的描述
- 模块目录描述更新为当前 13 个目录
- 删除"外部模块优先"规则说明

### E2 删除过时文档
- `docs/architecture/sumika-core-post-split-audit.md` — 审计完成，结论已合并到本计划
- `docs/architecture/audit-completeness-report.md` — 如存在则删除
- `modules/README.md` — 如存在则删除

---

## 执行顺序

```
Phase A ─── 独立，先做（保证新机器能安装）
    │
    ├── Phase B ─── 独立 QML 文件修改（与 A 无依赖）
    │
    ├── Phase C ─── 最重，分多步（C1→C2→C3→C4→C5→C6→C7 有顺序依赖）
    │   C1 启动脚本 → C2 settings bin → C3 顶层调度器 → C4 QML pages
    │   → C5 删除 Service → C6 module-actions → C7 CLI 工具
    │
    ├── Phase D ─── 在 C 之后（确保路径变量稳定）
    │
    └── Phase E ─── 最后收尾
```

每个 Phase 完成后 smoke test：`omd-restart` + bar 日志 zero error。
