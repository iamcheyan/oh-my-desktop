# NixOS 初始化流程

`Init.sh` 现在支持 NixOS。它的目标是让一个刚装好的 NixOS 用户先得到可运行的 Sumika Shell 用户环境，再把系统级配置交给用户自己的 NixOS flake 管理。

## 推荐流程（flake 管理）

```sh
git clone https://github.com/iamcheyan/oh-my-desktop.git ~/development/OMD
cd ~/development/OMD
./Init.sh
```

脚本在检测到 NixOS 后会：

1. 通过 `nix --extra-experimental-features 'nix-command flakes' profile add` 安装用户态运行依赖。
2. 安装 Hyprland/Quickshell、Wayland Portal、PipeWire、NetworkManager、蓝牙、音频、亮度、截图、壁纸和显示器工具。
3. **特别安装 `wlr-randr`**。显示器设置模块使用 `wlr-randr --json` 获取显示器、模式、刷新率和布局；缺少它会导致显示器设置页面为空。
4. 安装字体检查和基础工具。
5. 迁移旧 OMD 命名空间的配置（如果存在），创建 `~/.config/quickshell` 和 hypridle 运行时链接。
6. 修复壁纸运行状态、安装自定义 launcher，并创建 `uwsm-app` 兼容包装器。
7. 保留用户的 `~/.config/sumika-shell` 和 `.env`，不把凭据写入仓库。

如果检测到 `~/nixos-config/flake.nix`，脚本不会修改 `/etc/nixos/configuration.nix`，也不会猜测用户的 host 名称。需要把以下内容加入自己的 flake/module：

```nix
environment.systemPackages = with pkgs; [
  hyprland quickshell wlr-randr swaybg wl-clipboard
  grim slurp brightnessctl ddcutil
];
programs.hyprland.enable = true;
xdg.portal.enable = true;
services.pipewire.enable = true;
```

然后按自己的主机配置执行：

```sh
sudo nixos-rebuild switch --flake ~/nixos-config#<host>
```

推荐将 `wlr-randr` 放进系统包而不是只依赖用户 profile；这样 SDDM/新用户和回滚后的 generation 都能获得相同依赖。`Init.sh` 的 profile 安装是首次初始化和无 root 权限时的即时兜底。

## 非 flake 的旧式 NixOS

如果系统使用 `/etc/nixos/configuration.nix`，并且用户明确希望脚本修改系统配置，可以执行：

```sh
SUMIKA_NIXOS_APPLY_SYSTEM=1 ./Init.sh
```

脚本会先备份配置，再执行 dry-build；dry-build 或 switch 失败时恢复备份。默认不启用这个路径，避免覆盖用户已有配置。

## 数据迁移与安全

初始化代码和 QML 来自 Git 仓库；用户配置、扩展和运行状态是不同层次：

|内容|位置|处理方式|
|---|---|---|
|OMD 代码/QML|`~/development/OMD`|Git clone/pull|
|用户覆盖配置|`~/.config/sumika-shell`|chezmoi 或手工迁移|
|扩展|`~/.local/share/sumika-shell/extensions`|按扩展复制/安装|
|主题、显示器、壁纸状态|`~/.local/state/sumika-shell`|迁移前核对，允许重新生成|
|凭据/API key/NAS 密码|`~/.env`、权限 600 文件|只在本机注入，禁止提交公开仓库|

不要把旧机的绝对路径直接写进新机状态。例如壁纸目录、AppImage、Flatpak 架构和旧用户 profile 路径都必须在新机重新验证。

项目迁移时可以排除 `node_modules`、`target`、`dist`、`build`、缓存和可再生成的 Debug 构建，但**不能排除 OMD 根目录或模块内的 `bin/`**。`sumika-restart`、`sumika-overview`、`sumika-display-config` 等脚本缺失会造成黑屏、空启动器或空显示器设置页面。

## 初始化后的验证

```sh
command -v quickshell hyprctl wlr-randr swaybg
sumika-doctor
sumika-display-config get
systemctl --user --failed
```

进入 Sumika Shell 后，确认：

- 顶栏和应用启动器出现；
- 显示器设置显示 `eDP-1`/外接显示器、模式和缩放；
- 壁纸渲染器处于运行状态；
- `hyprctl monitors` 能看到所有输出；
- 手动注销/重新登录后仍能自动启动。

## 本次迁移中发现的差异

本次迁移没有直接运行 `Init.sh`，而是先复制代码、chezmoi、扩展和运行状态，再补齐依赖。由此发现两类容易遗漏的项目：

1. OMD 各级 `bin/` 脚本被错误排除，导致 Sumika 黑屏；
2. NixOS 系统没有 `wlr-randr`，导致显示器设置模块没有任何显示器属性。

这两项现在分别由 OMD 目录迁移规则和 NixOS 初始化依赖清单固定下来。
