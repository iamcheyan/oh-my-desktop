# Quickshell 配置指南

> 配置文件：`~/.config/quickshell/config.json`
> 修改后 Quickshell 会自动 reload

---

## appearance — 外观

```json
"appearance": {
    "extraBackgroundTint": true,
    "fonts": {
        "expressive": "Space Grotesk",
        "iconNerd": "Ubuntu Nerd Font",
        "main": "Google Sans Flex",
        "monospace": "Ubuntu Nerd Font",
        "numbers": "Google Sans Flex",
        "reading": "Readex Pro",
        "title": "Google Sans Flex"
    },
    "transparency": {
        "enable": false,
        "automatic": false,
        "backgroundTransparency": 0,
        "contentTransparency": 0
    },
    "wallpaperTheming": {
        "enableAppsAndShell": false,
        "enableQtApps": false,
        "enableTerminal": false
    }
}
```

| 字段 | 说明 |
|------|------|
| `extraBackgroundTint` | 额外背景色调 |
| `fonts.*` | 各用途字体设置 |
| `transparency.enable` | 是否启用透明效果 |
| `transparency.automatic` | 自动根据壁纸决定透明度 |
| `wallpaperTheming.*` | 基于壁纸自动生成配色（matugen） |

---

## apps — 应用路径

```json
"apps": {
    "terminal": "kitty -1",
    "bluetooth": "kcmshell6 kcm_bluetooth",
    "network": "kcmshell6 kcm_networkmanagement",
    "volumeMixer": "~/.config/hypr/hyprland/scripts/launch_first_available.sh ..."
}
```

点击 bar 上对应按钮时执行的命令。改成你自己的应用即可。

---

## audio — 音频保护

```json
"audio": {
    "protection": {
        "enable": true,
        "maxAllowed": 99,
        "maxAllowedIncrease": 10
    }
}
```

防止音量突然飙到 100%。`maxAllowed` 是最大允许音量，`maxAllowedIncrease` 是单次最大增幅。

---

## background — 桌面壁纸与小组件

```json
"background": {
    "wallpaperPath": "/path/to/wallpaper.png",
    "hideWhenFullscreen": true,
    "widgets": {
        "clock": { "enable": false, "style": "cookie" },
        "weather": { "enable": false }
    }
}
```

| 字段 | 说明 |
|------|------|
| `wallpaperPath` | 壁纸路径 |
| `hideWhenFullscreen` | 全屏时隐藏桌面小组件 |
| `widgets.clock.style` | 时钟样式：`cookie`（表盘）、`digital`（数字） |
| `widgets.weather.enable` | 显示天气小组件 |

---

## bar — 顶部栏

```json
"bar": {
    "bottom": false,
    "showBackground": true,
    "vertical": false,
    "cornerStyle": 0,
    "borderless": false,
    "rightModuleSpacing": 8,
    "rightModules": ["sidebar", "util:audio", "..."],
    "screenList": [],
    "showOnFocusedMonitorOnly": true,
    "weather": {
        "enable": true,
        "city": "tokyo",
        "enableGPS": true,
        "fetchInterval": 10,
        "useUSCS": false
    }
}
```

| 字段 | 说明 |
|------|------|
| `bottom` | `true` = 底部栏 |
| `showBackground` | 显示栏背景 |
| `cornerStyle` | `0` = Hug（贴边圆角）、`1` = Float（浮动） |
| `borderless` | 无边框模式 |
| `rightModules` | 右侧模块列表（顺序即显示顺序） |
| `rightModuleSpacing` | 右侧模块间距(px) |
| `screenList` | 空数组=所有屏幕；填屏幕名则只在指定屏幕显示 |
| `showOnFocusedMonitorOnly` | 只在聚焦屏幕显示 |
| `weather.city` | 天气城市 |
| `weather.enableGPS` | 用 GPS 自动定位 |

### 可用的 rightModules 值

```
sidebar          — 右侧栏按钮（含指示器）
util:audio       — 音频输出切换
util:idle        — 防休眠
util:nightlight  — 夜间模式
util:mic         — 麦克风开关
util:colorpicker — 取色器
util:screenshot  — 截图
util:clipboard   — 剪贴板
util:wifi        — WiFi
util:bluetooth   — 蓝牙
battery          — 电池
media            — 媒体控制
systray          — 系统托盘
spacer           — 弹性间距
weather          — 天气
```

---

## battery — 电池阈值

```json
"battery": {
    "critical": 5,
    "low": 20,
    "full": 101,
    "suspend": 3,
    "automaticSuspend": true
}
```

电量百分比阈值。`full: 101` 表示不显示充满状态。

---

## overview — 工作区总览

```json
"overview": {
    "enable": true,
    "columns": 5,
    "rows": 2,
    "scale": 0.18,
    "centerIcons": true,
    "orderBottomUp": false,
    "orderRightLeft": false
}
```

| 字段 | 说明 |
|------|------|
| `columns` / `rows` | 工作区网格列数/行数 |
| `scale` | 缩略图缩放比例 |
| `centerIcons` | 窗口图标居中显示 |
| `orderBottomUp` | 从下往上排列 |
| `orderRightLeft` | 从右往左排列 |

---

## notifications — 通知

```json
"notifications": {
    "timeout": 7000,
    "forceMonitor": {
        "enable": false,
        "name": ""
    }
}
```

`timeout` 单位毫秒。`forceMonitor` 可强制通知显示在指定屏幕。

---

## light — 夜间模式 & 防闪屏

```json
"light": {
    "night": {
        "automatic": false,
        "colorTemperature": 2513,
        "from": "19:00",
        "to": "06:30"
    },
    "antiFlashbang": {
        "enable": false
    }
}
```

`colorTemperature` 越低越暖（偏黄）。`antiFlashbang` 在亮色内容出现时短暂降低亮度。

---

## lock — 锁屏

```json
"lock": {
    "useHyprlock": false,
    "launchOnStartup": false,
    "centerClock": true,
    "showLockedText": true,
    "security": {
        "requirePasswordToPower": false,
        "unlockKeyring": true
    }
}
```

---

## time — 日期时间

```json
"time": {
    "dateFormat": "ddd, dd/MM",
    "shortDateFormat": "dd/MM",
    "pomodoro": {
        "focus": 1500,
        "breakTime": 300,
        "longBreak": 900,
        "cyclesBeforeLongBreak": 4
    }
}
```

日期格式遵循 Qt `QLocale` 格式。pomodoro 时间单位秒。

---

## tray — 系统托盘

```json
"tray": {
    "filterPassive": true,
    "invertPinnedItems": true,
    "monochromeIcons": true,
    "pinnedItems": ["Fcitx", "崩溃处理程序"],
    "showItemId": false
}
```

`pinnedItems` 是固定显示的托盘项名称。`filterPassive` 隐藏被动状态的图标。

---

## startup — 启动优化

```json
"startup": {
    "deferBackgroundTasks": true,
    "staggerPanelLoading": true,
    "tier1DelayMs": 1500,
    "tier2DelayMs": 6000,
    "backgroundTasksDelayMs": 4000
}
```

分层延迟加载，加快启动速度。一般不需要改。

---

## 其他

| 字段 | 说明 |
|------|------|
| `cheatsheet.*` | 快捷键提示面板样式 |
| `conflictKiller.autoKillTrays` | 自动杀掉冲突的托盘进程 |
| `hacks.arbitraryRaceConditionDelay` | 竞态条件延迟(ms) |
| `interactions.scrolling.*` | 滚动灵敏度 |
| `language.ui` | UI 语言 (`zh_CN`) |
| `launcher.pinnedApps` | 启动器固定应用 |
| `musicRecognition.*` | 音乐识别(Shazam) |
| `networking.userAgent` | 网络请求 UA |
| `osd.timeout` | OSD 显示时长(ms) |
| `regionSelector.*` | 截图区域选择器样式 |
| `resources.*` | 资源监控刷新间隔 |
| `screenRecord.savePath` | 录屏保存路径 |
| `search.imageSearch.*` | 以图搜图 |
| `sidebar.cornerOpen.*` | 角落触发侧栏 |
| `sounds.theme` | 音效主题 |
| `updates.*` | 更新检查设置 |
| `windows.centerTitle` | 窗口标题居中 |
