# Asahi Linux 刘海 (Notch) 显示说明

本机: Apple MacBook Pro (14-inch, M1 Max, 2021) — `j314c`

## 现状

Asahi 的 `appledrm` 内核模块控制刘海 region 是否暴露给用户态:

```
/sys/module/appledrm/parameters/show_notch    默认 N
/proc/device-tree/soc/dcp@38bc00000/apple,notch-height   0x004a = 74px
```

- `show_notch=N`(默认): 驱动只向 KMS 导出 `3024x1890@120` 模式,
  顶部 74px 的刘海物理区被驱动从 framebuffer 里裁掉、不上报,
  所以 Hyprland `hyprctl monitors all` 里**看不到** `3024x1964` 这个原生模式
  (`/sys/class/drm/card2-eDP-1/modes` 只有 `3024x1890`)。
- `show_notch=Y`: 驱动会导出原生分辨率 `3024x1964@120`,
  保留顶部中央 74px 的刘海物理遮挡区到 framebuffer 内,
  应用可以在那块以外的区域正常铺内容,但中央顶部会被物理刘海盖住。

## 启用原生刘海模式

`appledrm` 是开机时直接 built-in 加载(不走 modprobe), 所以 `/etc/modprobe.d/` 不一定起作用,
最稳的是把参数加到内核 cmdline:

```sh
# Fedora / Asahi (推荐用 grubby)
sudo grubby --update-kernel=ALL --args="appledrm.show_notch=1"

# 或者直接写 modprobe.d (如果是 module 加载方式)
echo "options appledrm show_notch=1" | sudo tee /etc/modprobe.d/appledrm.conf
```

改完重启。重启后验证:

```sh
cat /sys/module/appledrm/parameters/show_notch      # 应显示 Y
hyprctl monitors all | grep availableModes            # 应能看到 3024x1964
```

确认 1964 模式出来后,切到原生分辨率:

编辑 `omarchy/hypr/monitors.lua`:
```lua
hl.monitor({ output = "eDP-1", mode = "3024x1964@120", position = "0x0", scale = 2 })
```

然后 `hyprctl reload`。

## Bar 布局规避刘海

为避免时钟绘制到顶部中央被刘海盖住，当前 Bar 布局已在
`quickshell/modules/bar/BarContent.qml` 固定为中央留空、时钟在右侧。
不再通过旧版配置文件的 `centerModules` / `rightModules`
调整位置。Quickshell 热重载即可生效；HDMI 等外接显示器不受影响。

## Bar 高度自适应刘海

Bar 高度不是固定值, 由 `quickshell/services/HostInfo.qml` 的
`screenHasNotch` 判定驱动 (`quickshell/modules/common/Appearance.qml`):

```qml
property real baseBarHeight: HostInfo.screenHasNotch ? 32 : 26
```

- **有刘海 (32px)**: bar 需要盖住顶部刘海物理遮挡区, 保持原高度。
- **无刘海 (26px)**: 外接显示器/非 Apple 主机用更矮的 bar。

### 检测原理

两个条件同时满足才判定有刘海:

1. **Apple 主机**: `scripts/quickshell` 启动时同步读 `/proc/device-tree/model`,
   以 `SUMIKA_HOST_APPLE=1/0` 环境变量导出。QML 单例是懒加载的,
   异步 `Process` 读 model 会和首次高度求值竞态, 所以必须由 wrapper
   在引擎启动前导出。裸 `qs -p`(仅开发场景)时 HostInfo 内部的 `Process`
   作为回退, 约 50ms 后响应式翻转。
2. **屏幕宽高比 < 1.595**: 刘海面板物理上是 ~1.54 (如 3024x1964),
   无刘海面板是标准 16:10 (1.6)。阈值取中间值留出 scale 取整余量。
   用 Apple 主机做前置条件, 排除其他厂商 3:2 面板误判。

> 注意: 判定是**全局**的 —— 任一屏幕有刘海, 所有屏幕的 bar 都是 32。
> 合盖外接 (只剩 16:10 外屏) 时降为 26。按屏高度需要重构 Bar.qml, 未做。

### 图标随 bar 等比缩放

右侧图标槽和图标尺寸按设计比例 `icon:slot = 20:28` 随 bar 高度缩放,
避免矮 bar 下图标溢出或 hover 圆环贴边 (`Appearance.qml`):

```qml
property real rightIconSlotSize: Math.min(Config.options.bar.rightIconSlotWidth, baseBarHeight)
property real rightIconSize: Config.options.bar.rightIconSize
    * Math.min(1, rightIconSlotSize / Config.options.bar.rightIconSlotWidth)
```

| bar | slot | icon | 托盘图标(×0.82) |
|---|---|---|---|
| 32 (刘海) | 28 | 20 | 16 |
| 26 (无刘海) | 26 | 18.57 | 15 |
| 20 (假设) | 20 | 14.29 | 12 |

配置项 `bar.rightIconSlotWidth` / `bar.rightIconSize` 语义不变 (期望值),
渲染时统一取派生 token `Appearance.sizes.rightIconSlotSize` /
`Appearance.sizes.rightIconSize`。比例封顶 1: bar 变高图标不会超过配置值,
但用户显式配大的值 (如 icon > slot) 不会被吞。

## 回退

```sh
sudo grubby --update-kernel=ALL --remove-args="appledrm.show_notch=1"
# 改回 monitors.lua 用 3024x1890@120, 重启
```

## 参考

- `modinfo appledrm` → `show_notch:Use the full display height and shows the notch (bool)`
- `Documentation/gpu/asahi` (kernel source)
- DTB 节点: `/proc/device-tree/soc/dcp@38bc00000/apple,notch-height`
