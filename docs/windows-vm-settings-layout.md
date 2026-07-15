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

| State | Left primary | Right emphasis |
| --- | --- | --- |
| **Blocked** | Hero warning + Fix Requirements | Requirements checklist expanded |
| **Not installed** | Install Windows | Default/current specs preview |
| **Installing / fixing** | Progress + phase% + Open Console | Logs expanded |
| **Ready** | Connect | Connection details; Start/Stop secondary |
| **Stopped** | Start & Connect | Specs + Remove in danger zone |
| **Partial / broken** | Resume / Repair | Remove more visible but still confirm |

One primary button per state. Secondary actions never match its visual weight.

## Progressive Disclosure

| Level | Content |
| --- | --- |
| Primary | Health hero, one CTA, connection when configured |
| Secondary | Specs, Start/Stop, Open Console, Keep Alive |
| Advanced | Requirements rows, compose/storage paths, FreeRDP path, logs |
| Danger | Remove with two-step confirm (`SettingsDangerZone`) |

Logs: collapsed by default; auto-expand while `installing` or `fixing`.

## Implementation Notes

- Keep `QtObject` status model and Process helpers; fix `parseKeyValue` to split
  on real newlines (`"\n"`).
- Reuse `SettingsTokens`, `SettingsSection`, `SettingsDisclosure`,
  `SettingsDangerZone`, `ButtonRow`, `SettingsButton`.
- Footer remains Close only (actions are immediate).
- File: `quickshell/modules/settings/pages/WindowsVmPage.qml`

## Phases

### Phase A — Layout ✅ (2026-07-15)

Two-column shell, hero, demoted requirements/logs/paths, danger remove,
tokenized colors.

### Phase B — State-primary CTA ✅ (2026-07-15)

Single primary label per state; connection and power actions secondary.

### Phase C — Later (optional)

Editable RAM/CPU/Disk drafts, password display, dedicated Requirements/Logs
subpages.

## Success Criteria

- Healthy VM: Connect is obvious within two seconds
- Blocked host: one blocker sentence + Fix, checklist not competing with noise
- Installing: progress and logs visible without scrolling past five cards
- Remove is hard to hit accidentally and still two-step confirmed
