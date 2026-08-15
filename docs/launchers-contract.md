# Desktop Launcher 声明式契约

扩展通过 `module.json` 的 `contributes.launchers` 声明桌面快捷方式，由 shell 框架**自动同步**到 `~/.local/share/applications/sumika-*.desktop`。**扩展不需要写任何 QML 或 shell 代码**来管理 .desktop 文件。

---

## 声明格式

```json
{
  "contributes": {
    "launchers": [
      {
        "id": "sumika-file-backup",
        "name": "Sumika File Backup",
        "comment": "One-shot file backup to external storage",
        "exec": "sumika-launch-settings-backup-tui",
        "icon": "icon.png",
        "categories": ["System", "FileTools"],
        "terminal": false,
        "startupWmClass": "io.github.iamcheyan.sumika.backuptui",
        "noDisplay": false
      }
    ]
  }
}
```

### 字段说明

|字段|必填|类型|默认|说明|
|---|---|---|---|---|
|`id`|yes|string|—|全局唯一，**必须以 `sumika-` 开头**，如 `sumika-file-backup`。成为 .desktop 文件名 `<id>.desktop`|
|`name`|yes|string|—|`.desktop` 的 `Name=` 字段，应用菜单显示的名称|
|`comment`|no|string|—|`.desktop` 的 `Comment=`，鼠标悬停提示|
|`exec`|yes|string|—|命令行。`bin/` 目录已在 PATH 上，直接写脚本名即可|
|`icon`|no|string|—|图标路径。相对路径（相对于模块根目录）或绝对路径。SVG/PNG 均可|
|`categories`|no|string[]|`[]`|`.desktop` 的 `Categories=`。半角分号连接|
|`terminal`|no|bool|`false`|是否在终端中运行|
|`startupWmClass`|no|string|—|窗口类名，用于 Hyprland 浮动规则匹配|
|`noDisplay`|no|bool|`false`|设为 `true` 在应用菜单中隐藏（保留后台调用入口）|

> [!IMPORTANT]
> `id` 必须以 `sumika-` 开头——框架只管理 `sumika-*.desktop`，从不动用户其他 .desktop 文件。

---

## 生命周期

```
扩展启用 ──→ startup ──→ sumika-sync-launchers ──→ 生成 sumika-<id>.desktop
                                                       │
扩展禁用 ──→ ModuleLoader.syncLaunchers() ──→ 删除对应 .desktop
                                                       │
扩展卸载 ──→ 下次 startup ──→ 发现无 registry 条目 ──→ 僵尸清理
```

### 三种状态全覆盖

|场景|行为|触发机制|
|---|---|---|
|**启用**|写/刷新 .desktop|bar 启动 `sumika-sync-launchers` + QML config watch|
|**禁用**（`modules.disabled`）|删除 .desktop|`ModuleLoader` reactive watcher + 下次 startup|
|**卸载**（删目录）|僵尸自动清理|startup 扫描时发现 .desktop 无 registry 对应|

### 同步触发点

- **Bar 每次启动** → `quickshell/scripts/quickshell` 中调用 `sumika-sync-launchers --quiet`
- **`sumika.json` 的 `modules.disabled` / `modules.enabled` 变化** → `ModuleLoader.qml` 的 `on_DisabledModulesChanged` / `on_ModulesEnabledChanged` 调用 `syncLaunchers()` → 拉起 `sumika-sync-launchers --quiet`
- **registry 加载完成** → `ModuleLoader.registryLoaded()` 调用 `loader.syncLaunchers()`

**不变量：只有完整会话 shell（bar / settings）拥有 desktop 生命周期。**
轻量应用（polkit agent、按需 launcher/overview）使用 `modules-lite.json`
（仅核心模块、`contributes.launchers` 为空），且 `ModuleLoader.syncLaunchers()`
与 `sumika-sync-launchers` 双层拒绝从 lite 注册表同步——否则空视图会把
所有扩展 `.desktop` 当僵尸删除。

---

## 架构组件

### 总览

```
┌──────────────────────────────────────────────────────────────┐
│                       module.json                           │
│  "contributes.launchers": [ { id, name, exec, ... } ]       │
└──────────────┬───────────────────────────────────────────────┘
               │ 壳子启动合并 registry
               ▼
┌──────────────────────────────────────────────────────────────┐
│              modules.json (runtime registry)                 │
│  contributes.launchers: [ { ..., moduleId, source } ]       │
└──────────────┬───────────────────────────────────────────────┘
               │ sumika-sync-launchers — 读 registry + sumika.json
               ▼
┌──────────────────────────────────────────────────────────────┐
│     ~/.local/share/applications/sumika-*.desktop            │
│  (每个启用模块一个 .desktop 文件)                             │
└──────────────────────────────────────────────────────────────┘
```

### 各层职责

|层|文件|职责|
|---|---|---|
|**声明**|扩展的 `module.json`|`"contributes.launchers"` 数组，每个元素是一个 launcher 描述|
|**合并**|`quickshell/scripts/quickshell`|`jq` 将各模块的 launchers 注入 registry 的 `contributes.launchers[]`，注入 `moduleId`、`source`|
|**同步**|`bin/sumika-sync-launchers`|**核心** Python 脚本：读 registry → 读 sumika.json → 对比磁盘 → 写/删/清僵尸|
|**Reactive**|`quickshell/core/runtime/ModuleLoader.qml`|`launchers` 属性 + `syncLaunchers()` 方法 + config watcher|
|**校验**|`bin/sumika-module-validate`|检查 id 格式、必填字段、icon 路径是否存在（相对路径带 `..` 报错）|
|**Schema**|`share/schemas/sumika-module-v2.schema.json`|JSON Schema 约束 `contributes.launchers` 结构|

---

## 向后迁移

旧模式的三个扩展（`file-backup`、`windows-vm`、`keyboard-remap`）原在 QML 中用 `syncDesktopFile()` 管理 .desktop，涉及 `Process`、`FileView`、config watcher、`onCompleted` 等数十行样板。

迁移步骤：
1. `module.json` 加 `contributes.launchers` 声明
2. 删除 QML 中 `syncDesktopFile()` 函数、`desktopFilePath` 属性、`extensionRoot` 属性、两个 config watcher、`Component.onCompleted` 的相关调用
3. `sumika-module-validate` 通过后即可

**新扩展不需要写任何 .desktop 管理代码。**

---

## 环境变量

`sumika-sync-launchers` 遵循 AGENTS.md 的 Path API：

|环境变量|默认值|用途|
|---|---|---|
|`SUMIKA_MODULE_REGISTRY`|`$XDG_RUNTIME_DIR/sumika-shell/modules.json`|registry 路径|
|`SUMIKA_SHELL_CONFIG_HOME`|`$XDG_CONFIG_HOME/sumika-shell`|读取 sumika.json 判定模块启用状态|
|`XDG_DATA_HOME`|`~/.local/share`|applications 目录基址|

---

## 调试

```sh
# 查看当前所有 sumika 的 .desktop
ls -la ~/.local/share/applications/sumika-*.desktop

# 手动同步（带统计信息）
sumika-sync-launchers

# 预览改动但不执行
sumika-sync-launchers --dry-run

# 静默模式
sumika-sync-launchers --quiet

# 校验模块 manifest
sumika-module-validate ~/.local/share/sumika-shell/extensions/<id>/

# 编辑器 JSON Schema 补全
# VS Code: 在模块目录放 .vscode/settings.json:
{
  "json.schemas": [{
    "fileMatch": ["module.json"],
    "url": "file:///home/tetsuya/development/OMD/share/schemas/sumika-module-v2.schema.json"
  }]
}
```
