# OMD / Sumika Shell — 收尾昨晚中断的 Full Review（KNOWN High + 决策回传）

## 一、背景

昨晚在另一台机器完成了全项目 review + 大量 FIXED 提交（最后 commit `b8db596`）。
完整报告：`docs/reviews/2026-08-14-full-review.md`

**已完成（不要重做）**：C1–C2 Critical、H1–H10 High、M1–M12 Medium、S1–S7 Script 层。
**未完成（本 goal 目标）**：报告里 **KNOWN — High, needs a decision** 的 K1–K8，以及相关可安全落地的 Medium deferred。

仓库已 clone 到本机：`~/development/oh-my-desktop`（origin = iamcheyan/oh-my-desktop，branch master）。

## 二、终极目标

把 K1–K8 全部闭环：
1. **能安全自动修的直接修**并 commit+push
2. **需要产品/安全决策的**：不要猜、不要擅自选破坏性方案——写成「决策请求」文件，让看门狗/用户拍板后再继续

## 三、决策回传机制（强制）

当遇到必须用户拍板的点时：

1. 写文件：`docs/reviews/DECISIONS_PENDING.md`（追加，不要覆盖）
2. 每条决策固定格式：

```markdown
## DEC-NNN | <短标题> | 阻塞项 K?
- **现状**：…
- **风险**：…
- **选项**：
  - A) …（推荐/不推荐 + 理由）
  - B) …
  - C) …
- **你的默认建议**：A / B / C
- **若选 A 的改动范围**：哪些文件
- **状态**：WAITING
```

3. 同时在会话最终可见输出里用醒目标记：
   `【需要决策】DEC-NNN: <标题> — 见 docs/reviews/DECISIONS_PENDING.md`
4. **不要空等**：把不依赖该决策的其他 K 项继续做完；只有被该决策阻塞的代码路径才停
5. 用户/Hermes 回复决策后，把对应 DEC 状态改为 `DECIDED: A/B/C`，立即实施

## 四、K1–K8 处理策略

### K1 / K2 — polkit 过宽（安全，优先）
- 位置：
  - `file-backup/polkit/50-sumika-backup.rules`（子串匹配 `mount.cifs`）
  - `keyboard-remap/share/polkit-1/rules.d/50-sumika-keyboard.rules`
- **默认先做可逆加固，不必等决策**：
  1. 把规则从「命令行子串匹配」改为 **精确 argv0 / 专用 action id**
  2. 限制为 `wheel` 或专用 group（若系统无 group 则创建 `sumika` group 的规则注释说明）
  3. 若完整正确方案需要「专用 root helper + .policy」，写成 DEC-001，同时落地临时加固（方案 B quick）避免裸奔
- 验收：恶意 `pkexec bash -c 'mount.cifs # payload'` 不再放行；合法备份/键盘路径仍可用（在能测的范围内测）

### K3 — windows-vm 安全与缺失脚本
- RDP 脚本缺失、compose 密码 world-readable、`rm -rf` 无守卫
- **可直接做**：
  - 密码文件 chmod 600 + YAML 特殊字符转义
  - `rm -rf` 目标白名单/路径前缀校验（必须在 sumika 状态目录下）
  - 缺的 RDP launcher：若能从现有脚本拼出最小可用版就补；否则 DEC-002
- 不要删用户 VM 数据

### K4 — input-method schemas 空
- **可直接做**：把 4 个默认 schema 打进包，popup Repeater 读配置
- 验收：全新配置（无手写 schema）弹窗按钮有动作

### K5 — voice socket `/tmp` + 0666
- **可直接做**：迁到 `$XDG_RUNTIME_DIR/sumika-voice.sock`，mode 0600
- 同步改 QML/客户端连接路径；旧路径兼容一层（若存在则 warn）后删除
- 验收：socket 不在 /tmp、权限 0600、转写仍通（若本机无 voice 模型则至少路径/权限单测）

### K6 — sasayaki Go 数据竞争
- 读 `sasayaki` 扩展或关联 Go 代码，修：
  - 统一锁 owner（recorder 字段）
  - `opTranslate` / `testSpeechOnly` 加锁
  - Shutdown 加 stopCh，避免 120s 卡死
  - serve 防二次抢 socket
- 若 sasayaki 是独立仓库 symlink/子模块，在该仓库修并注明
- 有测试就跑；没有就 `go test ./...` 或至少 `go build`

### K7 — ModuleLoader overlays 从不实例化
- 在 bar ShellRoot（或报告指明的挂载点）用 Repeater 实例化 `overlays` 贡献
- 确认 night light / notification-popup overlay 能经 registry 加载
- 小心双实例（clock 的 ≤60s fallback 仍在时不要重复拉起）——保留 fallback 作兜底，registry 成功则 fallback 不再抢

### K8 — Quickshell IPC list/query 空返回
- 先复现：`qs ipc ... call action list` 是否仍空
- **可直接做 workaround**：list/status 改为 string 返回（JSON 文本），更新 `sumika-action` 解析
- 上游问题记入 docs，不阻塞

## 五、顺手可做（不阻塞，有余力）

从报告 KNOWN Medium/Low 里挑 **安全或明显死代码** 且改动面小的：
- screenshot 固定 `/tmp` 路径 → XDG_RUNTIME_DIR
- voice `/tmp` wav/pid 同类问题
- 删除确认过的死文件（`core/api/` 若报告说已删则跳过）
- AGENTS.md 模块数/主题路径漂移（报告已写，可再核对一次）

不要大重构、不要重写 website、不要重做已 FIXED 项。

## 六、执行顺序

1. 读 `docs/reviews/2026-08-14-full-review.md` 全文 + 当前树，确认 FIXED 已在 master
2. **安全优先**：K1/K2 临时加固 → K5 → K3 文件权限/rm 守卫
3. K4 → K7 → K8 → K6
4. 每修完一类：`sumika-doctor`（若环境无 compositor 则跳过 GUI，至少 shellcheck/语法/单元路径）
5. 持续更新 `docs/reviews/2026-08-14-full-review.md`：把已修的 K 标成 **FIXED (date)**，决策项链到 DECISIONS_PENDING.md
6. commit 信息中文或英文均可，风格与仓库历史一致（`fix(...):` / `docs(review):`）
7. **push origin master**

## 七、验收标准

1. K1–K8 每个要么 FIXED，要么在 DECISIONS_PENDING.md 有 WAITING/DECIDED 记录且不阻塞其它项
2. 无新增「任意用户 pkexec 提权」面（K1/K2 至少 quick 加固落地）
3. voice socket 不在世界可写 /tmp
4. windows-vm 密码文件 600 + rm 有守卫
5. 报告文档已更新状态
6. git push 成功，最终中文汇报：修了哪些、哪些等决策、如何复验

## 八、边界

- 工作目录：`~/development/oh-my-desktop`
- 不要改 chezmoi 源以外的 `~/.config/` 生产配置（除非文档明确要写 defaults 模板）
- 不要 `gh repo delete` / force push
- 本机可能无 Hyprland GUI——GUI 验证尽力；逻辑/权限/单元测试必须做
- 资源：其它 goal 并行中，避免长时间占满 CPU 的无意义循环；编译/go test 可以

## 九、给看门狗/用户的可见信号

- 需要决策时：输出含 `【需要决策】`
- 全部完成时：输出含 `【OMD收尾完成】` + 摘要
- 若卡死超过合理时间：把进度写入 `docs/reviews/FINISH_PROGRESS.md`
