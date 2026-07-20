# 仓库残遗代码审计 — 2026-07-20

> 方法:全仓 grep "0 引用" 扫描 + 已知架构知识交叉验证。简单 grep 有误判(legacy 包装
> 链、动态拼接、被 source 的脚本),所以每条标置信度。**高置信度可直接清;中/低需逐项
> 核实再清。**

## A. 高置信度死代码(可直接清)

### A1. quickshell 死服务 / 死组件
- `quickshell/services/ResourceUsage.qml` — **0 引用**,死服务。
- `quickshell/modules/common/widgets/`:
  - `TempScreenshotProcess.qml`、`ClippedFilledCircularProcess.qml`、`FadeLoader.qml`、
    `PointingHandLinkOverlay.qml`、`ToolbarPairedFab.qml`、`NotificationActionButton.qml`
    — 0 引用,死组件。

### A2. scripts/ 个人/遗留脚本(0 引用,与桌面运行无关)
- `scripts/wechat`、`scripts/wps`、`scripts/keepassxc`、`scripts/windows-rdp`、
  `scripts/remote-desktop`、`scripts/remote-desktop.conf` — 个人应用启动器,非 OMD 核心。
- `scripts/install-launchers` — 0 引用,dev 期遗留。
- `scripts/launch-tui-tool` — 0 引用,被 `omd-launch-settings-*-tui` 取代。
- `scripts/reload-terminals`、`scripts/omd-quickshell-stop.sh` — 0 引用,被
  `omd-restart`/`reload-quickshell` 取代?

> 建议:确认 `wechat/wps/keepassxc/windows-rdp/remote-desktop` 不是你要保留的个人快捷
> 启动器再删;OMD 核心相关脚本(`reload-*`/`omd-quickshell-stop`)核实是否被 alias 或
> 手动用。

### A3. docs/ 历史一次性文档(0 引用,无 AGENTS.md 索引)
这些是过去迭代的"计划/审计/交接"类文档,已无引用,可归档或删:
- `omarchy-cleanup-plan.md`、`omarchy-cleanup-summary.md`、
  `slimming-phase1-removal-plan.md`、`unused-runtime-code-audit-2026-07-11.md`、
  `performance-optimization-audit-2026-07-11.md`、`performance-optimization.md`、
  `project-handover-summary.md`、`process-split-implementation.md`、
  `settings-migration-plan.md`、`settings-migration-dms.md`、
  `reload-race-and-crashes.md`、`overview-drag-debug-log.md`、
  `overview-performance.md`、`overview-search-disabled.md`、
  `overview-workspace-ordering.md`、`session-review.md`、
  `clipboard-optimization-review.md`、`quickshell-performance-audit.md`、
  `cross-monitor-drag-preview-bug.md`、`omd-restart-cgroup-fix.md`、
  `asahi-bluetooth-keyboard-pairing.md`、`asahi-notch.md`、
  `gdm-hyprland-quickshell-session.md`、`omarchy-fedora-session.md`、
  `nixos-install-adaptation.md`、`bar-menu-system.md`、
  `notification-redesign.md`、`notification-system.md`、
  `display-settings-tui-redesign.md`、`settings-center-refactor.md`、
  `settings-keyboard-remap-tui.md`、`topbar-implementation.md`、
  `tui-color-mapping-system.md`、`unify-dialog-style.md`、
  `key-capture-and-extended-f-keys.md`、`third-party-deps.md`、
  `screenshot-tool-current-state.md`、`wifi-bluetooth-tui.md`、
  `bluetooth-wifi-tools-comparison.md`、`backup-tui.md`、`file-share-backup.md`。

> 建议:不直接删历史文档(有溯源价值),**归档到 `docs/archive/`** 一个动作解决,
> AGENTS.md 不用改(本就未索引)。

## B. 中置信度(需逐项核实)

### B1. bin/omd-* 0 引用(31 个)
grep 出 31 个 0 引用,但其中**一批是 legacy-omarchy 系统命令包装**(被 Hyprland 绑定
以 `omd-` 名调用,经 `bin/omd-legacy-omarchy` 转发),简单 grep 会漏。需在
`hypr/bindings.lua` + `hypr/default/` 里确认是否被绑定:
- 系统类(很可能被绑定):`omd-reboot` `omd-shutdown` `omd-system-lock` `omd-wake`
  `omd-polkit` — **先查绑定再决定**。
- 设置 TUI 启动器:`omd-launch-settings-keyboard-tui`(其它 4 个 theme/voice/windows/backup/ocr
  在 QML 里被引,唯独 keyboard 没被引——确认 keyboard 设置入口怎么开)。
- 截图/OCR:`omd-capture-screenshot` `omd-capture-text-extraction` `omd-settings-ocr`
  `omd-settings-ocr-tui` — 确认截图/OCR 流程是否还走这些。
- 其它:`omd-backup` `omd-bluetooth-tui` `omd-clipboard-store`(autostart 用?)
  `omd-doctor` `omd-edit-muted-apps` `omd-font-current` `omd-kitty-smart-paste`
  (kitty.conf 用!)`omd-launch-floating-terminal-with-presentation`
  `omd-launch-screensaver` `omd-settings-backup-tui` `omd-settings-keyboard`
  `omd-settings-keyboard-tui` `omd-settings-theme-tui` `omd-settings-vm-tui`
  `omd-settings-voice` `omd-settings-voice-tui` `omd-theme-bg-set`
  `omd-toggle-notification-silencing` `omd-wifi-tui` `omd-windows-vm`
  `omd-legacy-omarchy`(这是包装器本身,**不能删**)。

> 我的 grep 把 `omd-kitty-smart-paste` 判 0,但 `config/kitty/kitty.conf` 明显引用它
> (我之前改过)——说明 grep 漏了 `.conf`。**B1 整批不可信,必须用更全的引用扫描
> (含 .conf / .desktop / systemd unit / Hyprland 绑定动态拼接)重做。**

### B2. share/bin/omarchy-* 55/57 "0 引用"
这批是 vendored 上游 Omarchy 脚本,经 `omd-legacy-omarchy` 包装**间接**调用,所以
"0 直接引用"是**预期**的,不是死代码信号。要清这批必须做完整 call-graph(哪个
omd- 包装 → 哪个 omarchy-)。**本轮不处理**,单列长期项。

### B3. hypr/default/ 是否仍被加载
`hypr/hyprland.lua` 加载 `hypr/default/` 模块,但 OMD 自己的 `hypr/*.lua` 可能已
覆盖部分。需对比 default/ 与 OMD 用户模块的重叠,删 default 里被 OMD 完全取代的。
**需读 hyprland.lua 的加载顺序**再定。

### B4. quickshell 服务低引用(1-2 ref)
`ConflictKiller` `FirstRunExperience` `KeyringStorage` `Updates`(各 1 ref)——
确认那个引用是不是死路径(引用了但条件不可达)。

## C. 已确认保留(误判,别清)
- `bin/omd-legacy-omarchy` — legacy 包装器核心,删了整个 omd- 系统命令链断。
- `scripts/omd-path.sh` — 被 source,不是按名引用,grep 误判 0。
- QML 入口模块 `bar/overview/polkit`(0 `import` 引用)— app 进程入口,正常。
- `icons/`、`keyboard-remap/` — 都在用(ActiveWindow / KeyboardRemapPage)。
- `.pi-subagents/`(880K)— 已 gitignore,不在仓库,留。
- `config/{alacritty,foot,kitty,ghostty,nvim,fcitx5}/` — 终端/输入法配置,在用。

## D. 还在上轮未清的尾巴
- 5 个 docs 残留 `tui-go` 悬空指针(`tui-style-system` `voice-settings-redesign`
  `windows-vm-settings-layout` `theme-tui-color-impl-plan` `python-tui-port-report`)—
  各 1-5 处,改成指 Python 实现或删段。

## 建议执行顺序(给低成本模型)

1. **A1**(死 QML 服务/组件):直接删,跑 Quickshell 热重载确认不崩。
2. **A3**(历史 docs):移到 `docs/archive/`,零风险。
3. **A2**(个人脚本):逐个问用户确认是否保留个人启动器,其余删。
4. **B1**(bin/omd-*):**重做引用扫描**,扩展到 `.conf/.desktop/systemd/Hyprland 动态拼接`,
   再逐个定生死。**别用我这次的 grep 结果删 bin/omd-***。
5. **B3**(hypr/default):读 hyprland.lua 加载链,对比 OMD 用户模块,删被完全取代的。
6. **B4** 低引用服务:核实引用是否可达。
7. **B2**(omarchy-* 55 个):长期项,做完整 call-graph,本轮跳过。
8. **D**:5 个 docs 的 tui-go 悬空指针清理。

## 执行回填(执行模型完成后填)

- [x] **A1** 删除: `quickshell/services/ResourceUsage.qml`、`quickshell/modules/common/utils/TempScreenshotProcess.qml`、`widgets/ClippedFilledCircularProgress.qml`、`widgets/FadeLoader.qml`、`widgets/PointingHandLinkHover.qml`、`widgets/ToolbarPairedFab.qml`、`widgets/NotificationActionButton.qml`。**7 个文件**,无 import 引用。`omd-restart` 后 4 个 systemd unit 正常启动,无 QML 错误。
  - 注:审计说 `TempScreenshotProcess.qml` 在 `widgets/`,实际在 `utils/`。`PointingHandLinkOverlay` 不存在,只有 `PointingHandLinkHover`(0 ref,也删了)。
- [x] **A3** 归档 41 个历史文档到 `docs/archive/`,使用 `git mv`。AGENTS.md 未改(本就不索引这些)。
- [x] **A2** `install-launchers`、`launch-tui-tool` 直接删(被取代的 dev 脚本)。个人启动器(wechat/wps/keepassxc/windows-rdp/remote-desktop/*.conf)、`reload-terminals`、`omd-quickshell-stop.sh` 未获用户确认前保留不动。
- [x] **B1** 重扫:扩展引用源到 `.conf/.desktop/systemd/$PATH 调用/Hyprland 绑定(含 `paths.omd_root .. "/bin/omd-XXX"` 拼接)/`omd-legacy-omarchy` case 映射。确认死的 6 个删:
  - `omd-capture-screenshot`(symlink → legacy),`omd-capture-text-extraction`(symlink → legacy),`omd-system-lock`(symlink → legacy → `omarchy-system-lock`,但 `omd-lock` 也做同样的事),`omd-toggle-notification-silencing`(symlink → legacy,UI 无入口),`omd-doctor`(独立脚本,0 ref,仅 AGENTS.md 提及),`omd-edit-muted-apps`(通过 `omd-launch-tui` 调 `omarchy-edit-muted-apps`,但 Notifications.qml 直接用 `xdg-terminal-exec` 开 `vi`,不走此包装)。
  - 同步删 `hypr/looknfeel.lua` 中 `org.omd.omarchy-edit-muted-apps` 的窗口规则(1 行)。
  - 以下**保留**(有引用):omd-bluetooth-tui→omd-launch-bluetooth, omd-clipboard-store→omd-restart, omd-font-current→legacy, omd-launch-settings-keyboard-tui→omd-settings, omd-polkit→omd-restart, omd-reboot→legacy, omd-settings-backup-tui→omd-settings-tui, omd-settings-keyboard→omd-settings-tui, omd-settings-*-tui→omd-settings-tui, omd-shutdown→legacy, omd-theme-bg-set→omd-wallpaper, omd-wifi-tui→omd-launch-wifi, omd-windows-vm→legacy。
- [x] **B3** `hypr/default/` 无删:加载顺序是 `base.lua` → `default.hypr.{autostart,bindings.*,envs,looknfeel,input,windows,apps}` → 然后 `hypr/*.lua`(monitors, input, bindings, looknfeel, autostart)。用户模块追加在 default 之上,不取代。删 default 模块会丢失兜底配置。
- [x] **B4** `ConflictKiller.qml`、`FirstRunExperience.qml`、`Updates.qml` — 0 QML import 引用,删。`KeyringStorage.qml` 在 `LockScreen.qml` 有 2 处调用(活的),保留。
- [x] **D** 5 个 docs 的 `tui-go` 悬空指针清理:
  - `python-tui-port-report.md`:替换 Go pages 参考段落,删除 `cd tui-go; go test` 行
  - `tui-style-system.md`:替换"Go Settings TUI Styling Guidelines"为"Python TUI Styling Guidelines"
  - `voice-settings-redesign.md`:Phase 5 标题改为"Python TUI state pages",路径改为 `bin/omd-settings-voice-tui`
  - `windows-vm-settings-layout.md":Go Settings TUI 节改为 Python TUI,Phase C 同理,Phase D 一句"Go TUI"改为"Python TUI"
  - `theme-tui-color-impl-plan.md:原 Go 原型引用改为"原 Go 原型(已移除)"

### 偏离记录

1. A2 个人脚本留了 wechat/wps/keepassxc/... — 用户未确认,不擅自删。
2. `TempScreenshotProcess.qml` 位于 `utils/` 而非审计说的 `widgets/` — 仍被删(0 ref)。
3. `PointingHandLinkOverlay` 不存在,删了 `PointingHandLinkHover`(0 ref)。
4. B3 hypr/default 无删 — 覆盖逻辑但用户模块不取代 default,安全优先。
5. pytest 1/6 失败(`test_unknown_hero_tone_has_a_safe_fallback`) — 前次框架重构遗留,非本次清理引入。