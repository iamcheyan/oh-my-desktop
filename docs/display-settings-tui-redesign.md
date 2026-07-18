# Display Settings Visual Redesign — Options

Status: **deferred**. An experimental implementation of option B was tried and
fully reverted. Keep this note for a later decision; do not treat any of these
layouts as current runtime behavior.

Current runtime remains the dual-column Displays page documented in
[`settings-layout-system.md`](settings-layout-system.md) and
[`settings-center.md`](settings-center.md).

## Context

After an earlier pass on the Displays panel, the page still felt closer to a
full “system settings” form than to OMD’s shell language:

| Surface | Feel |
| --- | --- |
| Displays settings (before redesign) | Dual panel cards, helper descriptions, GNOME/Cosmic Settings-like |
| OMD Tools / bar popups | Single column, `PopupHeader`, flat rows, little nested chrome |

Goal discussed: more **TUI-like** without becoming pure character UI, or closer
to the **bar popup** style — without losing the display configuration model
(canvas, drafts, Discard/Apply, `wlr-randr` via `omd-display-config`).

## Shared constraints (all options)

Keep regardless of visual direction:

- Transaction model: one Discard / Apply over `DisplayConfigState` drafts
- Canvas drag for multi-monitor layout position
- Separate resolution vs refresh controls (one mode string under the hood)
- Identify / Detect as immediate actions (not footer transactions)
- `wlr-randr` as a diagnostic exit for hardware details

Do not invent a third visual system that matches neither bar popups nor the
current settings shell.

---

## Option A — Popup-native

Make Displays feel like a **large BarStatusPopup**.

```text
┌─ Display ──────────────────────────────────┐
│  🖥  eDP-1 · 3024×1964 @120 · 200%         │
│  ────────────────────────────────────────  │
│  [ compact monitor canvas ]                │
│  ────────────────────────────────────────  │
│  🖥  eDP-1                    Focused   >  │  ← ToolLauncherRow-like
│  Resolution              3024 × 1964    ▾  │  ← no helper description
│  Refresh rate                  120 Hz   ▾  │
│  Scale                          200%    ▾  │
│  Orientation                  Normal    ▾  │
│  Advanced…                              >  │
│                                            │
│  Identify · Detect          Discard Apply  │
└────────────────────────────────────────────┘
```

**Moves**

- Drop dual nested panel cards; one surface
- Header like `PopupHeader`
- List rows like tools content
- Descriptions off by default

**Pros:** Same family as OMD Tools / bar popups  
**Cons:** Single column gets long with multi-monitor + canvas + form  
**Best if:** Displays should feel like an expanded quick-setting

---

## Option B — TUI-panel (tried, then reverted)

Structured like a **terminal panel**, with real GUI controls. Not ASCII chrome.

### Visual language

```text
Section labels     muted uppercase (LAYOUT / OUTPUTS / MODE)
Key/value rows     label left ····· value right ▾  (no boxed dropdown)
List selection     › marker + accent wash (not a heavy card border)
Chrome             outer shell only; no dual nested panel cards
Graphic surface    monitor canvas is the only filled graphic block
Pending state      accent rail (not a full panel border)
Actions            flat Identify / Detect; footer keeps Close / Discard / Apply
```

### Layout evolution during the experiment

1. **Wide dual column, no cards** — left LAYOUT/OUTPUTS, right MODE  
2. **Dropped Advanced x/y** — position canvas-only; `wlr-randr` always visible  
3. **Single column** — header → LAYOUT (canvas fills spare height) → OUTPUTS
   (multi only) → MODE → hw  
4. **Compact dialog** (~560–640 wide) so single-column content is not stretched

### Shared widgets that would support this (reverted)

```text
SettingsTuiSection        uppercase section + optional headerActions / fillAvailable
SettingsTuiDropdownRow    whole-row key/value dropdown
SettingsButton { flat }   ghost actions
SettingsDisclosure { tui } uppercase advanced header (other pages)
```

**Pros:** Distinct OMD “desktop TUI” feel; denser than settings forms  
**Cons (why it felt less usable in practice)**

- Single column + large canvas can dominate mode controls
- Compact width helps density but changes the roomy dual-pane workflow
- Removing x/y editors is a real capability cut (even if canvas covers multi-monitor)
- Leader-dot rows + monospace read as “theme demo” more than “efficient tool” for some users
- Divergence from other settings pages until those also migrate

**Best if:** Displays is a **tool panel**, not a settings chapter — and the
information architecture is tuned carefully (what stays always visible vs
collapsed).

---

## Option C — Hybrid reduce (smallest change)

Keep dual-column master-detail; only subtract chrome and copy.

**Moves**

1. Drop helper descriptions under each dropdown  
2. Merge Display mode + Scale into one section; keep Advanced collapsed  
3. Shrink detail header (or `PopupHeader`-like one line)  
4. Soften dual panel cards (divider only, or canvas as sole raised surface)  
5. Lighter Identify / Detect (text/icon, not two heavy equal buttons)  
6. Align output list row height/hover with tools popup rows  

**Pros:** Low risk; keeps proven dual-pane IA  
**Cons:** Still reads as Settings, not TUI/popup  
**Best if:** Current structure is fine and only density/chrome should improve

---

## Suggested decision path (when revisiting)

1. Decide **which family** Displays belongs to: bar popup (A), TUI tool (B), or
   settings form (C / current).  
2. Prefer **C first** if the only complaint is “too much UI text/chrome.”  
3. Only commit to **B** if ready to redefine Displays as a compact tool and
   accept a different size/IA than Network/Voice dual-column pages.  
4. Avoid **A full single-column** for multi-monitor until canvas height and
   scroll behavior are designed.

## Non-goals for a future redesign

- Pure character-cell / ncurses UI
- Per-output Apply buttons (stay one transaction)
- Replacing canvas drag with only numeric position fields
- Hard-coding accent colors outside `TuiStyle` / Omarchy theme tokens

## Related docs

- [`settings-center.md`](settings-center.md) — runtime model, Displays ownership  
- [`settings-layout-system.md`](settings-layout-system.md) — current layout contract  
- [`tui-style-system.md`](tui-style-system.md) — shared shell tokens  
- [`settings-panel-ux-optimization.md`](settings-panel-ux-optimization.md) — normal vs advanced actions
