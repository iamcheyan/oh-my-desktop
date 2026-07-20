# File Share / Backup

Date: 2026-07-19

SMB 文件共享与定时备份工具。通过 Python curses TUI 配置和管理。

## 文件

| 文件 | 作用 |
|---|---|
| `bin/omd-settings-backup-tui` | Python curses TUI 主程序 |
| `bin/omd-backup` | 后端脚本，封装 smbclient 操作 |
| `bin/omd-launch-settings-backup-tui` | 启动器（入口） |

## 配置

配置文件：`~/.config/omd/file-share-backup/config.json`

```json
{
  "_guide":       "== File Share / Backup Configuration ==",
  "_guide1":      "Edit this file directly, or use the TUI (E key to open).",
  "_help_paths":  "localPath: array of local directories to back up",
  "address":      "192.168.3.10",
  "share":        "NAS",
  "user":         "tetsuya",
  "password":     "cccccc",
  "localPath":    ["/home/tetsuya/下载/", "/home/tetsuya/图片/"],
  "remotePath":   "/Backups",
  "includeExt":   ".pdf,.doc",
  "excludeExt":   ".tmp,.log",
  "scheduleType": "manual",
  "scheduleValue": ""
}
```

| 字段 | 类型 | 说明 |
|---|---|---|
| `address` | string | SMB 服务器地址 |
| `share` | string | 共享名 |
| `user` | string | SMB 用户名 |
| `password` | string | SMB 密码 |
| `localPath` | string[] | 本地待备份目录列表（数组，支持多条） |
| `remotePath` | string | 远程目标路径 |
| `includeExt` | string | 逗号分隔的包含扩展名（空=全部） |
| `excludeExt` | string | 逗号分隔的排除扩展名 |
| `scheduleType` | string | `manual` / `every_h` / `every_d` / `at_time` |
| `scheduleValue` | string | 数值或 HH:MM 时间 |

以 `_` 开头的字段为说明注释，TUI 加载时自动保留，修改配置时不会被删除。

## TUI 布局

```
┌────────────┬──────────────────────────────┐
│ Status     │  Connection                   │
│  ● 已连接   │  Address: 192.168.3.10       │
│  //192...  │  Share: NAS                   │
├────────────┤  User: tetsuya                │
│ Schedule   │  Password: ****                │
│  [X] Manual│  Local paths: 2 paths         │
│  [ ] Every │  Remote path: /Backups        │
│  h         │  Include ext: ...             │
│  [ ] Every │  Exclude ext: ...             │
│  d         ├──────────────────────────────┤
│  [ ] At    │  Sync Status                  │
│  time      │  Last sync: 10:30  ✅         │
├────────────├──────────────────────────────┤
│ Actions    │  Activity                     │
│  t Test    │  $ backup started             │
│  s Sync    │  completed in 5s              │
│  c Compare │  │ scrollbar │               │
│  e Config  │                               │
└────────────┴──────────────────────────────┘
```

## 操作

| 按键 | 作用 |
|---|---|
| `Tab` | 切换左/右区域 |
| `↑ ↓` | 导航 |
| `Enter` | 编辑字段 / 选择计划（确认后自动保存并刷新比对） |
| `t` | 测试 SMB 连接 |
| `s` | 执行同步 / 备份 |
| `c` | 详细比对差异（彩色显示新增/修改/删除/无变化） |
| `e` | 在新终端窗口中用 vi 打开配置文件 |
| `l` | 查看远程备份文件列表 |
| `r` | 刷新状态（重新加载配置和比对） |
| `q` | 退出 |

## 编辑配置

配置进行了**自动保存（Auto-Save）**设计：
1. 在 TUI 中直接编辑字段并回车确认后，会自动保存并触发后台文件比对，无需手动保存。
2. 按 `e` 键会：
   * 在新终端窗口中用 `vi` 打开 `~/.config/omd/file-share-backup/config.json`
3. 编辑完关闭终端后，按 `r` 重新加载

## 后端 omd-backup

```bash
omd-backup test          # 测试 SMB 连接并挂载
omd-backup backup        # 执行 rsync 备份
omd-backup compare       # 基于 MD5 缓存的差异比对
omd-backup compare -v    # 详细比对（每文件彩色输出）
omd-backup list          # 浏览远程已备份文件
omd-backup status        # 显示挂载/配置状态
omd-backup load-config   # 输出当前配置 JSON
```

备份流程：
1. 读取 `config.json` 获取 SMB 凭据和路径
2. 通过 `mount.cifs` 挂载 SMB 共享到本地（`~/NAS/`）
3. 用 `rsync -a` 增量同步本地文件到远程
4. 备份完成后保存 MD5 哈希缓存供下次比对使用
5. 挂载保持在线，可供文件管理器直接浏览

## 入口

- **Bar 工具菜单**：OMD Tools → File Share / Backup
- **设置概览页**：OMD Tools → File Share / Backup
- **命令行**：`omd-launch-settings-backup-tui` 或 `omd-settings-tui backup`
