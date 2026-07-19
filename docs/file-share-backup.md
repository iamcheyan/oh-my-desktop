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

配置文件：`~/.config/omd/backup/config.json`

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
│  b Backup  │  upload photo.jpg             │
│  s Save    │  completed in 5s              │
│  E Config  │  │ scrollbar │               │
└────────────┴──────────────────────────────┘
```

## 操作

| 按键 | 作用 |
|---|---|
| `Tab` | 切换左/右区域 |
| `↑ ↓` | 导航 |
| `Enter` | 编辑字段 / 选择计划 |
| `t` | 测试 SMB 连接 |
| `b` | 执行备份 |
| `s` | 保存配置 |
| `E` | 在新终端窗口中用 vi 打开配置文件 |
| `r` | 刷新（编辑配置后重新加载） |
| `q` | 退出 |

## 编辑配置

按 `E` 键会：
1. 自动保存当前配置
2. 在新终端窗口中用 `vi` 打开 `~/.config/omd/backup/config.json`
3. 编辑完关闭终端后，按 `r` 重新加载

## 后端 omd-backup

```bash
omd-backup test          # 测试 SMB 连接
omd-backup backup        # 执行备份（读取 config.json）
omd-backup load-config   # 输出当前配置 JSON
omd-backup save-config   # 从标准输入写入配置
```

备份流程：
1. 读取 `config.json` 获取 SMB 凭据和路径
2. 遍历 `localPath` 中的每个本地目录
3. 按 `includeExt` / `excludeExt` 过滤文件
4. 用 `smbclient put` 上传到远程 `//address/share/remotePath/`
5. 每个本地目录会在远程创建同名子目录

## 入口

- **Bar 工具菜单**：OMD Tools → File Share / Backup
- **设置概览页**：OMD Tools → File Share / Backup
- **命令行**：`omd-launch-settings-backup-tui` 或 `omd-settings-tui backup`
