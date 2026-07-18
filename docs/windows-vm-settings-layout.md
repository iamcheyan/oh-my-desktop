# Windows VM Settings Layout

Date: 2026-07-15

## Relation To Prior Redesign

`docs/windows-vm-settings-redesign.md` (2026-07-12) defined the **backend
contract and state machine**. That work is largely done:

- `bin/omd-settings-windows-vm` is the single helper
- status fields, install/start/connect/remove, progress, RDP conflict handling

This document covers the **layout and information architecture** pass so the
page matches Display / Sound / Voice:

- wide master–detail columns
- one health hero + one primary CTA
- progressive disclosure for requirements, paths, and logs

Backend behavior should stay stable; the QML page reorganizes the same `status`
and action commands.

## Problems After The Functional Redesign

| Problem | Symptom |
| --- | --- |
| Single-column card stack | Windows VM → Requirements → Setup → Progress → Manage → Logs |
| Status duplication | Subtitle + pills + Phase + Container restating the same state |
| Flat action hierarchy | Connect / Keep Alive / Start / Stop equal-weight button rows |
| Debug noise on root | Storage paths, shared folder, full log pane always competing |
| Requirements always loud | Checklist visible even when the VM is healthy |
| Hard-coded colors | `#e53935` / `#f9a825` instead of `SettingsTokens` |

## Target Layout

### Wide (`width >= 980`)

```text
┌──────────────────────────────┬──────────────────────────────┐
│ LEFT · Status & primary CTA  │ RIGHT · Connect & ops        │
│                              │                              │
│ [Hero]                       │ Connection                   │
│  Ready / Installing / …      │  Web · RDP endpoint          │
│  one-line detail             │  Connect / Keep Alive        │
│  blocker sentence if needed  │  Start / Stop                │
│                              │                              │
│ [Primary action]             │ Specs                        │
│  Install / Fix / Connect     │  RAM · CPU · Disk · User     │
│  progress (install only)     │                              │
│  action text / error         │ Advanced                     │
│                              │  Requirements checklist      │
│ [Refresh]                    │  Paths · FreeRDP bin         │
│                              │  Logs (auto-open if install)│
│                              │  Danger: Remove              │
└──────────────────────────────┴──────────────────────────────┘
footer: Close
```

### Narrow

Single column: hero + primary → connection → specs → advanced.

## State Views

| State | Primary CTA | Right pane | Hidden until relevant |
| --- | --- | --- | --- |
| **Blocked** | Fix requirements | none (single column) | Connection, specs, logs, power, remove |
| **Not installed** | Install Windows | none (single column) | Connection, runtime, manage, logs, remove |
| **Installing / fixing / booting** | Open console / wait | Logs expanded | Remove (optional), connect |
| **Ready** | Connect | Connection + short logs | Requirements checklist |
| **Stopped** | Start | Specs / connection | Requirements checklist |
| **Partial / broken** | Repair / start | Logs + status | — |

One primary action per state (`→ label (enter)`). Secondary actions are plain
key-annotated lines, never equal visual weight. Fake status “buttons”
(Docker/KVM/RDP pills) are not used — blockers are written as failed checks
with human-readable detail.

## Progressive Disclosure

| Level | Content | When shown |
| --- | --- | --- |
| Hero | Status light + one-line situation | Always |
| Blockers | Only **failed** host checks + detail | `blocked` only |
| Install guide | What install does + defaults | `install` only |
| Primary CTA | One next step | Always |
| Secondary ops | Console / stop / start only | VM running or stopped |
| Connection / specs | Endpoints, RAM/CPU/disk | Ready / stopped / repair |
| Logs | Container output | Booting, busy, repair, ready side pane |
| Danger | Remove with `y` / `n` confirm | Configured VM only |

Logs: hidden before a VM exists; auto-shown while installing, fixing, or booting.

## Go Settings TUI (`tui-go`)

Canonical interactive page:

- File: `tui-go/internal/pages/windows/model.go`
- Backend: `bin/omd-settings-windows-vm`
- Layout rules match `docs/tui-style-system.md` (borderless dashboard, no
  pill-buttons for non-interactive status).

State rendering is branch-based (`blockedView`, `installView`, `readyView`, …)
rather than one form with every section always visible.

### Example: current host blocked + not installed

```text
● Windows VM
  Host requirements need attention before install.

WHAT'S BLOCKING
Only failed checks are listed. Fix these, then install.

✗ Docker access
  permission denied while trying to connect to the docker API…
✗ Free disk space
  49 GB free (need ≥ 74 GB)

NEXT STEP
Resolve host requirements before install or start.
→ Fix requirements (enter)
  Refresh status (r)
```

No Connection / Runtime / empty Specs / empty Logs until install is possible.

## QML Settings Center (legacy panel)

- Keep `QtObject` status model and Process helpers; fix `parseKeyValue` to split
  on real newlines (`"\n"`).
- Reuse `SettingsTokens`, `SettingsSection`, `SettingsDisclosure`,
  `SettingsDangerZone`, `ButtonRow`, `SettingsButton`.
- Footer remains Close only (actions are immediate).
- File: `quickshell/modules/settings/pages/WindowsVmPage.qml`

QML should follow the same progressive disclosure table when next touched.

## Phases

### Phase A — Layout ✅ (2026-07-15)

Two-column shell, hero, demoted requirements/logs/paths, danger remove,
tokenized colors.

### Phase B — State-primary CTA ✅ (2026-07-15)

Single primary label per state; connection and power actions secondary.

### Phase C — Go TUI state pages ✅ (2026-07-18)

`tui-go` Windows page is state-driven: blocked/install are single-column
guided flows; manage/logs only appear after a VM exists or during work.

### Phase D — Later (optional)

Editable RAM/CPU/Disk drafts, password display, dedicated Requirements/Logs
subpages; align QML panel with Go TUI disclosure rules.

## Success Criteria

- Healthy VM: Connect is obvious within two seconds
- Blocked host: only failed checks + Fix; no manage/connect noise
- Not installed (host OK): Install is the only primary path; no empty panels
- Installing: progress and logs visible without scrolling past five cards
- Remove is hard to hit accidentally and still two-step confirmed

## Related

Disk / ISO / peak-space research (why 74 GB, what actually downloads):
`docs/windows-vm-settings-redesign.md` § *Disk & Image Size Research*.
