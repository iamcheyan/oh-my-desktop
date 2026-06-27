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

为避免时钟绘制到顶部中央被刘海盖住,把时钟从 `centerModules` 移到 `rightModules`,
让中央留空给刘海:

`quickshell/config.json` 里:
```json
"centerModules": ["media"],
"rightModules": [
  "sidebar", "util:audio", "util:idle", "util:nightlight",
  "util:mic", "util:colorpicker", "util:screenshot", "util:clipboard",
  "util:wifi", "util:bluetooth", "clock", "battery",
  "systray", "spacer"
]
```

`clock` 已在 `RightModuleRegistry.qml` 里补注册,无需再改代码。
Quickshell 热重载即可生效;HDMI 等外接显示器不受影响。

## 回退

```sh
sudo grubby --update-kernel=ALL --remove-args="appledrm.show_notch=1"
# 改回 monitors.lua 用 3024x1890@120, 重启
```

## 参考

- `modinfo appledrm` → `show_notch:Use the full display height and shows the notch (bool)`
- `Documentation/gpu/asahi` (kernel source)
- DTB 节点: `/proc/device-tree/soc/dcp@38bc00000/apple,notch-height`