# Voice Settings Redesign

Date: 2026-07-15

## Goal

The Voice Input settings panel should feel like **input-method settings**, not
an engine ops dashboard. Opening it must answer three questions immediately:

1. Can I use voice input right now?
2. How do I trigger it?
3. Where do I go when something is wrong?

Secondary diagnostics, raw paths, and external TUI tools must not compete with
everyday configuration.

## Problems In Current UI

Observed in `quickshell/modules/settings/pages/VoicePage.qml` (pre-redesign):

| Problem | Symptom |
| --- | --- |
| Status duplication | Pills (`ready`, model size, daemon) plus `Engine state` plus card subtitle all restate the same health info |
| No hierarchy | Record / Recheck as equal full-width buttons; diagnostics, paths, and daily actions share the same card weight |
| Unreadable bindings | Raw tokens such as `HANGUL_HANJA`, `0X100811D0`, `XF86Tools` with no primary vs secondary distinction |
| Kick-out flow | Configure / Capture Key / TUI Test / Diagnose dismiss the panel and open external tools |
| Debug noise on the root view | Cache/model/venv/socket paths sit at the same level as “can I record?” |
| Single-column card stack | Large empty regions and short cards; unlike Display/Sound’s master–detail structure |

## Design Principles

Align with `docs/settings-layout-system.md` and `docs/settings-panel-ux-optimization.md`:

1. **One primary task** — readiness + trial record + trigger keys.
2. **Progressive disclosure** — paths, full diagnose TUI, and raw engine paths live under Advanced.
3. **Borrow Display/Sound layout contract, not their metaphors** — wide two-column panels, narrow single column; no fake monitor canvas.
4. **Immediate actions stay near content** — trial record next to status; recheck is secondary.
5. **Footer stays simple** — voice config is mostly instant-apply; footer remains Close only (no Discard/Apply unless bindings become a draft transaction later).

## Target Layout

### Wide layout (`width >= 980`)

```text
┌──────────────────────────────┬──────────────────────────────┐
│ LEFT · Live / Status         │ RIGHT · Configure            │
│                              │                              │
│ [Hero]                       │ Keybindings                  │
│  status title                │  primary: Alt+A        [del] │
│  SenseVoice · 229 MB         │  extra: Globe, F13…    [del] │
│  daemon note (one line)      │  Esc cancels while recording │
│                              │  [Add key] [Advanced TUI]    │
│ [Trial record]               │                              │
│  primary: Record / Stop      │ Behavior (phase 4)           │
│  duration while recording    │  auto-paste note / toggles   │
│  last result text block      │                              │
│  last error when present     │ Model & engine               │
│                              │  model ready · recheck       │
│ [Recent history]             │  setup when needed           │
│  last 3–5 lines or empty     │                              │
│  clear history (secondary)   │ Advanced (collapsed)         │
│                              │  paths, socket, full TUI     │
│                              │  diagnose / voice-test-tui   │
└──────────────────────────────┴──────────────────────────────┘
footer: Close
```

### Narrow layout

Single column: status + trial → keybindings → model → advanced.

### Setup state

When `VoiceInput.state === "setup"`, the left hero becomes a short install path:

1. Install environment
2. Download model
3. Trial record

Do not bury Setup as a twin of Recheck.

## Unified Health Model

Collapse multi-pill status into one primary result plus one detail line:

| Health | When | Primary copy |
| --- | --- | --- |
| Needs setup | `state === "setup"` or missing model/venv | Needs setup |
| Recording | `state === "recording"` | Recording… |
| Transcribing | `state === "transcribing"` | Transcribing… |
| Error | `state === "error"` or non-empty lastError while idle | Error |
| Ready | `state === "idle"` and model present | Ready |

Detail line examples:

- `SenseVoice · 229 MB · daemon idle`
- `SenseVoice · 229 MB · daemon running`
- `Model missing · run setup`

Do not show separate “Engine state: idle” rows once the hero covers it.

## Keybindings UX

File of record remains:

```text
~/.config/omd/config/voice_bindings.txt
```

(Hyprland loads the same path via `hypr/bindings.lua`.)

UI requirements:

1. **Friendly display names** over raw keysyms / codes.
2. **First line = primary trigger**; remaining lines are extras.
3. **Inline delete** for each row (rewrite file + `hyprctl reload`).
4. **Add key** uses capture (`key-test --hotkey`); prefer returning to Settings when possible.
5. **Advanced TUI** (`voice-bind-tui`) stays as a secondary “edit list in terminal” path.
6. Document recording-only **Esc cancels** as system behavior, not a user binding row.

Suggested friendly map (extend as needed):

| Stored value | Display |
| --- | --- |
| `ALT + A` | Alt + A |
| `code:472` | Globe (Fn) |
| `HANGUL_HANJA` | Hangul / Hanja |
| `XF86Tools` / `TOOLS` | F13 / Tools |
| `0X100811D0` | Hangul / Hanja (raw) |
| `code:N` | Keycode N |

## Behavior (later phase)

Expose real preferences only when they change runtime behavior:

- Auto-paste after success (if ever optional)
- History retention / clear policy
- Optional: push-to-talk vs toggle, paste-per-app, mic source via Sound page

Until then, state auto-paste as a short readonly note if it is always on.

## Diagnostics Hierarchy

| Level | Content | Placement |
| --- | --- | --- |
| In-page | Health hero, last error, trial result | Root left column |
| Secondary | Recheck / setup / restart daemon | Model section |
| Advanced | Paths, socket, full `voice-diagnose`, `voice-test-tui` | Collapsed disclosure |

## Phased Delivery

### Phase 1 — Structure ✅ (2026-07-15)

- Two-column wide layout / single column narrow
- Merged health hero; remove redundant engine-state rows
- One primary trial-record action; Recheck secondary
- Inline last result / last error
- Recent history (compact) with empty state
- Paths and external TUIs under Advanced disclosure
- Button hierarchy: one primary, secondaries not twin full-width bars

### Phase 2 — Keybindings ✅ (2026-07-15)

- Friendly labels
- Primary vs extra
- Inline delete + reload
- Add key captures without dismissing Settings (reads `key-capture.json` / clipboard)
- Edit in TUI remains secondary

### Phase 3 — In-page checklist diagnose

- venv / model / daemon / parecord / wl-copy checklist without opening curses TUI first

### Phase 4 — Behavior + setup wizard

- Real preference toggles where applicable
- Dedicated setup flow when engine is not installed

### Phase 5 — Python TUI state pages ✅ (2026-07-18)

`bin/omd-settings-voice-tui` follows the same progressive disclosure
pattern as the Windows VM TUI:

| State | What the user sees |
| --- | --- |
| **nomodel** | Setup guide only: what will install (~229 MB model + venv), primary Setup |
| **downloading** | Progress bar + Cancel; no bindings/tools |
| **recording** | Live timer + Stop & transcribe |
| **idle (ready)** | Trial record, model summary, bindings, recent; Advanced demoted |

Day-to-day settings (bindings, diagnose, test TUI, paths) stay hidden until the
engine is installed. Typographic actions (`→ label (enter)`) match wallpaper /
Windows VM styling; no fake status pills.

## Non-Goals

- Replacing the Python daemon or SenseVoice pipeline
- Moving voice settings into the bar popup (bar stays quick actions only)
- Full Discard/Apply transaction for every control
- Copying Display’s monitor canvas literally

## Implementation Touchpoints

| File | Role |
| --- | --- |
| `quickshell/modules/settings/pages/VoicePage.qml` | Main UI rewrite |
| `quickshell/services/VoiceInput.qml` | Existing state machine (extend only if setup/checklist need it) |
| `~/.config/omd/config/voice_bindings.txt` | Bindings storage |
| `hypr/bindings.lua` | Loads bindings after reload |
| `scripts/voice-bind-tui` | Advanced bindings editor |
| `scripts/key-test-launcher` / `key-test` | Capture path |
| `docs/voice-input.md` | Architecture; link to this redesign |
| `docs/settings-layout-system.md` | Shared layout contract |

## Success Criteria

- User can open Voice settings and understand readiness in under two seconds
- Trial record is the obvious primary action
- Bindings are readable; user can remove a bad binding without TUI
- Paths/socket/diagnose are available but not on the first visual scan
- Wide layout matches Display/Sound panel density and column rhythm
