# Pending Decisions

Decisions that need the owner's call before the full (non-quick) fix lands.
Reply with e.g. `DEC-001: A` and the corresponding work executes immediately.

---

## DEC-001 | Replace pkexec bash payloads with dedicated root helpers | 阻塞项 K1/K2
- **现状**：`file-backup` 与 `keyboard-remap` 通过 `pkexec bash -c '<payload>'`
  提权执行 mount/keyd 安装。2026-08-14 已落地**临时加固**（quick fix）：
  - `50-sumika-backup.rules`：只放行 argv0 恰为 `mount.cifs`/`umount` 的精确
    程序路径（禁止任何 bash 包装），并要求 `subject.active` + `wheel` 或
    `sumika` 组。
  - `50-sumika-keyboard.rules`：bash payload 被钉死为单一固定形态
    （`set -eu; mkdir -p /etc/keyd; install -m 0644 '<path>' /etc/keyd/sumika.conf;
    systemctl enable keyd || true; systemctl restart keyd || true`），路径段
    禁止引号/空格/`;`/`$`；同样要求 active + 组成员。
  - 16 项 polkit 规则仿真测试全部通过（恶意 `pkexec bash -c 'mount.cifs # …'`
    等载荷均被拒绝，合法路径放行）。
- **风险**：加固规则仍属"模式匹配"防线。`file-backup` 的 `sumika-backup`
  二进制是预编译 stripped aarch64 ELF（源仓库 `github.com/iamcheyan/sumika`
  当前 404/私有），无法重编译它改用专用 helper；`keyboard-remap` 的 payload
  固定形态依赖脚本与规则同步维护，未来改 payload 而忘了改规则会静默退回
  密码弹窗（fail-safe，但体验回退）。
- **选项**：
  - A) **专用 root helper + 独立 .policy action**（完整正确方案）：为
    backup-mount / keyboard-apply 各写一个小型 root helper（Go 或 sh），
    安装到 `/usr/libexec/sumika-*`，配套
    `org.sumika.backup.mount` / `org.sumika.keyboard.apply` policy 文件，
    pkexec 只以精确 action id 授权，不再解析命令行。（推荐 —— 把信任边界
    从"字符串形态"收敛到"二进制 + action id"；不推荐现在做的原因是
    file-backup 二进制无法在本仓重建，需要先恢复其源码仓库）
  - B) 维持现状（2026-08 加固版规则）：模式匹配但组限制 + active 限制 +
    精确形态校验。风险=未来 payload/规则漂移。
  - C) 移除免密规则，全部退回 polkit 密码弹窗：最保守，牺牲备份/键盘
    一键体验。
- **你的默认建议**：A（在 file-backup 源码仓库可访问之后实施；之前先保持 B）
- **若选 A 的改动范围**：新 helper 源码 + `packaging/`（deb/rpm 安装目标）、
  两扩展的 `polkit/` 目录改为 `.policy` 文件、`bin/` 调用方改 exec helper、
  `docs/features/backup-tui.md` + `docs/features/keyboard-remap.md` 更新、
  polkit 仿真测试改为 action-id 匹配。
- **状态**：WAITING
