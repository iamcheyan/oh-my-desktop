# File Share & Backup TUI

A terminal user interface for managing SMB/CIFS file share backups. Uses `mount.cifs` to mount a remote share and `rsync` for fast incremental sync.

---

## Quick Start

```
~/.config/omd/bin/omd-settings-backup-tui
```

Or press the backup button in the system bar.

### Initial Setup

1. **Fill in the connection fields** (left panel, tab/arrows to navigate):
   - **Address** — SMB server IP or hostname (e.g. `192.168.3.10`)
   - **Share** — Share name (e.g. `NAS`)
   - **User / Password** — SMB credentials
   - **Remote path** — Subdirectory under the share root (default: `Backups`)
   - **Local path(s)** — Comma-separated paths to back up

2. **Press `t` to test** — mounts the share via `pkexec` polkit dialog. Once mounted, the share stays accessible at `~/<ShareName>/` (e.g. `~/NAS/`).

3. **Press `s` to sync** — runs `rsync -a` to sync local files to `Backups/<System>-<Hostname>/` on the share.

---

## Key Bindings

| Key | Action | Description |
|-----|--------|-------------|
| `t` | Test connection | Mount share (polkit popup if needed) |
| `s` | Sync / Backup now | Rsync local files to remote share |
| `c` | Compare changes | Per-file diff with color (new/modified/deleted/unchanged) |
| `e` | Edit config file | Open config in `vi` via floating terminal |
| `l` | Browse remote | Open floating terminal with remote file listing |
| `r` | Refresh status | Reload config + item table + run quick compare |
| Tab | Switch panel | Toggle focus between left (config) and right (items/log) |
| ↑↓/jk | Navigate / scroll | Move through config fields or scroll log |
| Enter / Space | Edit / select | Edit the focused field or select schedule type |
| Esc / q | Back / quit | Cancel editing or exit TUI |

---

## Workflow

### First time
```
Fill config → t (test/mount) → s (sync) → c (verify diff)
```

### Daily use
```
t (mount if not already) → s (sync) → c (check diff)
```

### Browse backed-up files
```
l → floating terminal shows file tree on the remote share
```

### Check what would change without syncing
```
c → shows each file with color prefix:
   + filename  (green)  — new, not yet backed up
   ~ filename  (yellow) — modified since last backup
   - filename  (red)    — deleted locally, still in cache
   = filename  (gray)   — unchanged, up to date
```

---

## Visual Indicator

The hero line shows a right-aligned status dot:

| Status | Color | Meaning |
|--------|-------|---------|
| `● Synced` | Green | All files up to date |
| `● Needs sync` | Yellow | Changes detected since last backup |
| `● Disconnected` | Red | Share not mounted |
| `● Not tested` | Gray | Never tested/connected |
| `● Backing up…` | Green | Backup in progress |

---

## Architecture

### Backend: `bin/omd-backup`

A bash script that manages the full backup lifecycle:

```
┌─────────────┐     ┌──────────────┐     ┌───────────┐
│ mount.cifs  │────→│  rsync -a    │────→│  umount   │
│ (pkexec)    │     │  incremental │     │  (optional)│
└─────────────┘     └──────────────┘     └───────────┘
```

**Commands:**

| Command | Purpose |
|---------|---------|
| `mount` | Mount SMB share via `mount.cifs`. Tries direct first; if permission denied, falls back to `pkexec mount.cifs ...` (polkit dialog). If `pkexec` unavailable, prints setup instructions. |
| `unmount` | `umount ~/NAS` |
| `test` | Mount + report status |
| `backup` | Mount (if needed) → `rsync -a --delete src/ dest/` → save MD5 cache → save per-item timestamps |
| `compare` | Walk local files, compute MD5 hashes, diff against `md5-cache.json`. `--verbose` flag outputs per-file markers. |
| `list` | Mount (if needed) → show file tree from `~/NAS/Backups/<host-prefix>/` |
| `status` | Report config state + mount state as JSON |
| `save-config` / `load-config` | Read/write JSON config from stdin |

### Frontend: `bin/omd-settings-backup-tui`

A Python curses TUI with two-panel layout:

```
┌─────────────────────────────────────────────────┐
│ Backup Settings                              ● Synced │
│ File Share & Backup · SMB · $HOME            │
├──────────────────────┬──────────────────────────┤
│  ○ Connected         │  Name    Type  Files  Ch. │
│  //192.168.3.10/NAS  │  下载/   dir   466    21  │
│  Last sync: 14:22 ✅ │  图片/   dir    4     0  │
│                      │  opencode.… file   1     0  │
│  ┌Schedule─────────┐ │                          │
│  │ ○ Manual        │ │  ┌Activity──────────────┐│
│  │ ○ Hourly        │ │  │ $ compare — verbose  ││
│  │ ○ Daily         │ │  │ + 下载/ubuntu.iso    ││
│  │ ○ Custom        │ │  │ ~ 下载/config.yaml   ││
│  └─────────────────┘ │  │ - 下载/old.deb       ││
│  Address: 192.168... │  │ = 下载/readme.txt    ││
│  Share: NAS          │  └──────────────────────┘│
│  User: tetsuya       │                          │
│  Remote path: Backups│                          │
│  Local paths: ...    │                          │
│  ┌Actions──────────┐ │                          │
│  │ Test conn (t)   │ │                          │
│  │ Sync now (s)   │ │                          │
│  │ Compare chg (c) │ │                          │
│  │ Browse rem (l)  │ │                          │
│  │ Edit file (e)   │ │                          │
│  │ Refresh (r)     │ │                          │
│  └─────────────────┘ │                          │
├──────────────────────┴──────────────────────────┤
│ arrows:navigate tab:area s:sync c:compare r:refresh ... │
└─────────────────────────────────────────────────┘
```

#### Left Panel (config)
- **Status** — Connection status + last sync info
- **Schedule** — Manual / Hourly / Daily / Custom
- **Connection fields** — Address, Share, User, Password, Remote path, Local paths, File filters
- **Actions** — All available operations

#### Right Panel
- **Managed Items table** — Per-path name, type, file count, change count, last backup time, status badge
- **Activity log** — Scrollable log with command output. Color-tagged entries render in color:
  - `+` new files in green
  - `~` modified in yellow
  - `-` deleted in red
  - `=` unchanged in gray

### Shared module: `bin/omd_tui_shared.py`

Provides visual primitives used by all 5 TUIs (backup, voice, keyboard, VM, theme):

- `draw_log_in_area()` — renders a scrollable log area; supports `(tag, text)` tuples for colored entries
- `hero_line()` / `draw_hero()` — standard 2-row hero header with right-aligned status
- `draw_border()` / `draw_thick_border()` — box drawing
- `action_line()` / `primary_line()` / `danger_action_line()` — action button primitives
- `TAG_STYLE` — maps tag names to curses color attributes (ok=green, warn=yellow, danger=red, muted=gray, etc.)

---

## Compare Logic (MD5 Cache)

```
                  ┌─────────────┐
                  │ md5-cache   │
                  │ .json       │
                  └──────┬──────┘
                         │ read
                         ▼
  Local files ──→ md5sum ──→ compare hashes ──→ result
                         │                       │
                         │ write after backup    ▼
                         ▼                  {new, modified,
                  ┌─────────────┐           deleted, unchanged}
                  │ md5-cache   │
                  │ .json       │
                  └─────────────┘
```

1. Walk all configured local paths (recursive for directories)
2. Compute MD5 hash for each file
3. Compare against cached hashes from last successful backup
4. Classify each file:
   - **NEW** (`+`) — exists locally, not in cache → green
   - **MODIFIED** (`~`) — hash differs → yellow
   - **DELETED** (`-`) — in cache but not on disk → red
   - **UNCHANGED** (`=`) — hash matches → gray
5. After backup completes, cache is updated with current hashes

This approach is entirely local — no remote access needed for comparison.

---

## Polkit Integration

The TUI uses `pkexec` to elevate `mount.cifs` when direct mount fails:

```
mount.cifs //server/share ~/NAS  →  Permission denied
         ↓
pkexec mount.cifs //server/share ~/NAS  →  Polkit dialog pops up
         ↓
         User authenticates → mount succeeds → share stays mounted
```

### Optional: Passwordless polkit

Install the provided rule to skip the password prompt for `mount.cifs`:

```bash
sudo install -m 0644 \
  ~/.config/omd/share/polkit-1/rules.d/50-omd-backup.rules \
  /etc/polkit-1/rules.d/
```

### Alternative: setcap (no dialog at all)

```bash
sudo setcap cap_sys_admin+ep /sbin/mount.cifs
```

After this, `mount.cifs` runs directly without any elevation.

---

## Configuration And State

| Path | Purpose |
|------|---------|
| `~/.config/sumika-shell/file-share-backup/config.json` | Connection and path configuration |
| `~/.local/state/sumika-shell/file-share-backup/.smbcreds` | Generated SMB credentials; mode `0600` |
| `~/.local/state/sumika-shell/file-share-backup/items.json` | Per-path last-backup timestamps |
| `~/.local/state/sumika-shell/file-share-backup/md5-cache.json` | Cached file hashes |
| `~/.local/state/sumika-shell/file-share-backup/last-result.json` | Last backup result |
| `~/.local/state/sumika-shell/file-share-backup/last-compare.json` | Last comparison result |

---

## TUI Terminal Action Pattern

When a terminal window is needed (e.g. `e` edit or `l` browse), the TUI uses this launcher cascade:

1. `xdg-terminal-exec` (preferred)
2. `foot` (fallback)
3. `kitty` (last resort)

Each terminal action uses a unique `org.omd.<purpose>` app-id/class so Hyprland can apply a custom floating window rule (defined in `hypr/looknfeel.lua`). The terminal process is detached via `subprocess.Popen(..., start_new_session=True)`.

See full convention in `AGENTS.md` under *TUI Terminal Action Pattern*.

---

## Troubleshooting

### "mount.cifs not set up for user"

The script lacks permission to mount. See [Polkit Integration](#polkit-integration) or [setcap alternative](#alternative-setcap-no-dialog-at-all).

### "mount.cifs not found"

Install cifs-utils:
```bash
sudo pacman -S cifs-utils        # Arch
sudo apt install cifs-utils      # Debian
sudo dnf install cifs-utils      # Fedora
```

### "Connection timeout"

- Check network connectivity: `ping 192.168.3.10`
- Check SMB service: `smbclient -L //192.168.3.10/NAS -U tetsuya`
- Verify credentials in config

### Compare shows "file not found"

Configured local path doesn't exist. Update the path or remove it from config.

### Files not showing in backup

- Check `includeExt` / `excludeExt` filters
- Only files matching the filter patterns are included
- Single files (not in a directory) are always included
