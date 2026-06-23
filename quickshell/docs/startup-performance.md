# QuickShell (ii) 启动性能分析

> 分析日期：2026-06-20  
> 环境：Fedora / quickshell 0.2.1 / 配置 `~/.config/quickshell`

## 结论（先说）

**启动慢的主要原因不是资源文件太大，而是这套 Illogical Impulse shell 功能完整、模块多，启动时要同时做大量 QML 解析和系统调用。**

| 因素 | 是否主因 |
|------|----------|
| 图片 / 资源体积 | 否（总计约 5.6 MB） |
| QML 代码量（580 文件 / ~5.6 万行） | **是** |
| 46 个 Singleton 服务初始化 | **是** |
| 20 个面板模块在 `Config.ready` 后同时加载 | **是** |
| 启动时大量外部命令（hyprctl、nmcli、cliphist 等） | **是** |

---

## 配置体量

| 项目 | 数值 |
|------|------|
| 配置目录总大小 | **5.6 MB** |
| QML 文件数 | **580** |
| QML 代码行数 | **~56,578** |
| Singleton 服务 | **46** |
| 面板模块（ii 家族） | **20** |
| 最大单个资源 | `default_wallpaper.png` **137 KB** |
| 翻译文件（zh_CN） | **42 KB / 722 条** |
| 启动后内存（RSS） | **~430 MB** |

目录分布：

- `modules/` — 3.1 MB（代码为主）
- `assets/` — 1.3 MB
- `translations/` — 596 KB
- `services/` — 380 KB

---

## 实测启动时间线

通过 `quickshell -c ii -vv --log-times` 采集（2026-06-20）：

| 时间点 | 事件 |
|--------|------|
| **0 ms** | 开始加载 `shell.qml` |
| **~180 ms** | 扫描完全部 580 个 QML，生成模块索引 |
| **~900 ms** | QML 引擎开始实例化 Singleton 服务 |
| **~1,150 ms** | 扫描 582 个 `.desktop` 应用条目 |
| **~1,364 ms** | **状态栏 + 壁纸背景 layer 出现**（用户可见的核心 UI） |
| **~2,700 ms** | RegionSelector 等模块继续加载 |
| **~10 s** | 通知弹窗等 layer 陆续创建 |
| **~19 s** | Overview 等重型模块完全就绪 |

因此：

- 若感觉「慢」，可能是 **状态栏 1–2 秒已出现，但后台仍在加载十几秒**。
- 首次登录后按 Super 搜索，若模块尚未加载完，会有短暂无响应。

---

## 架构层面的原因

### 1. 所有面板在配置就绪后同时激活

`PanelLoader` 原先的条件是 `Config.ready && extraCondition`，导致 ii 家族 **20 个模块同时开始加载**：

```qml
// panelFamilies/IllogicalImpulseFamily.qml（优化前）
PanelLoader { component: Bar {} }
PanelLoader { component: Overview {} }
PanelLoader { component: SidebarRight {} }
// ... 共 19 个（SidebarLeft 已删除）
```

虽然用了 `LazyLoader`，但「懒」只体现在未实例化组件；**一旦 `Config.ready`，全部排队编译**。

### 2. `shell.qml` 启动时主动触发后台任务

```qml
Component.onCompleted: {
    MaterialThemeLoader.reapplyTheme()
    Hyprsunset.load()
    FirstRunExperience.load()
    ConflictKiller.load()
    Cliphist.refresh()      // 读剪贴板历史
    Wallpapers.load()
    Updates.load()          // 触发更新检查链
}
```

### 3. Singleton 服务在初始化时跑外部命令

部分服务在创建时 `running: true`，例如：

| 服务 | 启动时行为 |
|------|------------|
| `HyprlandData` | 5 个 `hyprctl` 进程 |
| `Network` | 多个 `nmcli` |
| `Translation` | `find` 扫描翻译目录 + 解析 JSON |
| `Ai` | 扫描 Ollama 模型、列出 prompt 文件 |
| `Updates` | `which checkupdates` + 包数量检查 |
| `AppSearch` | 预处理全部 desktop 条目 |
| `ResourceUsage` | 读 `/proc` + `lscpu` |

单个命令很快（毫秒级），但数量多、与 QML 编译并行时会叠加延迟。

### 4. 用户配置加剧加载

`~/.config/illogical-impulse/config.json` 中：

- `sidebar.keepRightSidebarLoaded: true` — 右侧边栏关闭时仍保持内容加载
- `updates.enableCheck: true` — 启动即检查系统更新
- ~~`policies.ai`~~ — 已移除 AI 功能

### 5. 壁纸颜色量化

`Appearance.qml` 中的 `ColorQuantizer` 在启动时分析壁纸颜色，用于透明度计算，会占用 CPU。

---

## 精简进度

- **AI 全套已删除**（2026-06-20）— 详见 [slimming-guide.md](./slimming-guide.md)
- **Waffle 全套已删除**（2026-06-20）— 详见 [slimming-guide.md](./slimming-guide.md)
- **按模块继续精简** — 使用 [slimming-guide.md](./slimming-guide.md) 中的表格逐步删除

---

## 已实施的优化（Phase 1）

### 代码改动

1. **`Config.options.startup`** — 新增启动调优配置项
2. **`PanelLoader`** — 支持分档延迟加载（tier 0 / 1 / 2）
3. **`IllogicalImpulseFamily`** — 按优先级分档面板
4. **`shell.qml`** — 延迟 `Cliphist.refresh()`
5. **`Updates.qml`** — 可延迟首次更新检查
6. **`Config.qml` 默认值** — `keepRightSidebarLoaded` 改为 `false`

> 注：`Ai.qml` 及全部 AI 相关代码已于 2026-06-20 移除，见 [slimming-guide.md](./slimming-guide.md)。

### 分档策略

| 档位 | 延迟 | 模块 |
|------|------|------|
| **Tier 0** | 立即 | Bar、Background、ScreenCorners、OSD、通知弹窗、锁屏 |
| **Tier 1** | 1.5 s | Overview、AppLauncher、RegionSelector、侧边栏、Session、Cheatsheet、OSK、Polkit |
| **Tier 2** | 6 s | Dock、MediaControls、Overlay、ScreenTranslator、WallpaperSelector |

> Tier 1 模块含全局快捷键。延迟 1.5 s 是为了让状态栏先就绪；登录后立刻按快捷键的极端情况，最多等待 1.5 s。

### 用户配置

`~/.config/illogical-impulse/config.json` 已写入对应 `startup` 段，并将 `keepRightSidebarLoaded` 设为 `false`。

---

## 后续可做的优化（Phase 2+）

按收益排序：

1. **关闭不用的功能** — 天气、AI 侧边栏、更新检查、背景小部件
2. **固定 UI 语言** — 已用 `zh_CN`，避免 `auto` 触发额外探测
3. **生成 `colors.json`** — 避免 `MaterialThemeLoader` 失败重试
4. **RegionSelector JSON 报错** — 排查 `RegionSelection.qml` 的 `hyprctl` 解析
5. **按需加载 Singleton** — 将 Booru、SongRec、LatexRenderer 等改为首次使用时初始化
6. ~~**减少 ii + waffle 双家族**~~ — 已移除 Waffle（2026-06-20）

---

## 如何验证优化效果

```bash
# 结束现有实例后重新启动并打日志
pkill quickshell
quickshell -c ii -vv --log-times -d

# 查看 layer 出现时间
LOG=$(ls -t /run/user/1000/quickshell/by-id/*/log.log | head -1)
grep 'openlayer>>quickshell:' "$LOG" | head -20
```

关注：

- `quickshell:bar` / `quickshell:background` 出现时间（目标 < 1.5 s）
- `quickshell:overview` 出现时间（目标明显早于优化前的 ~19 s）
- 进程 RSS（`ps -o rss -p $(pgrep quickshell)`）

---

## 调优参数参考

在 `~/.config/illogical-impulse/config.json` 的 `startup` 段：

```json
{
  "startup": {
    "staggerPanelLoading": true,
    "tier1DelayMs": 1500,
    "tier2DelayMs": 6000,
    "deferBackgroundTasks": true,
    "backgroundTasksDelayMs": 4000,
    "deferUpdateCheck": true,
    "updateCheckDelayMs": 30000
  }
}
```

- 设为 `false` / `0` 可恢复原先「全部立即加载」行为
- 若常用截图快捷键，可将 `tier1DelayMs` 降到 `500`
