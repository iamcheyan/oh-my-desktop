# Go Settings TUI Visual System

Date: 2026-07-19

## Goal

The four Go settings routes must look like **one product series**, not four
independent TUIs:

```text
bin/omd-settings-tui theme
bin/omd-settings-tui voice
bin/omd-settings-tui keyboard
bin/omd-settings-tui windows
```

Shared shell, shared control language, shared focus and section hierarchy.
Feature pages own **content and domain state only**. They must not invent local
button chrome, section title styles, page padding, or focus markers.

This document is the visual/structure contract for `tui-go/`. Backend contracts
(`omd-settings-*` helpers, key=value status) stay as documented in
`docs/settings-tui-go.md`. Per-page information architecture remains in:

- `docs/appearance-settings-layout.md`
- `docs/voice-settings-redesign.md`
- `docs/keyboard-remap-settings-layout.md`
- `docs/windows-vm-settings-layout.md`

Those docs still define **what** each page shows. This doc defines **how every
page is framed and controlled**.

---

## Design Principles

1. **One shell** — every page uses the same outer layout, padding, help bar, and
   optional pending footer.
2. **Text-first controls** — ordinary actions are plain text with mnemonics.
   Bordered “chips” are not default buttons.
3. **Accent is scarce** — accent color is for title health, focus, primary CTA,
   and true selection. Section headers stay muted.
4. **Borders mean surfaces** — borders wrap cards, previews, and modals only.
   Never wrap Setup / Refresh / cycle values / secondary actions.
5. **Pages differ by content, not dialect** — theme grid, voice logs, keyboard
   presets, and Windows state machines may differ; chrome may not.
6. **Thin pages** — layout math and styles live in `tui-go/internal/ui/`. Pages
   assemble strings with shared helpers.

---

## Page Shell Contract

Every route’s `View()` must reduce to the shared shell:

```text
┌─────────────────────────────────────────────────────────────┐
│  ● Title                                       working…     │  hero
│  one-line subtitle · context                                │
├──────────────────────────────┬──────────────────────────────┤
│ LEFT                         │ RIGHT (optional)             │
│  Section                     │  Section                     │
│  content                     │  content                     │
│  actions                     │  logs / detail / advanced    │
├──────────────────────────────┴──────────────────────────────┤
│ key label  key label  …                                     │  help
│ Pending changes · Apply (a) · Discard (x)   ← only if draft │  pending
└─────────────────────────────────────────────────────────────┘
```

### Ownership

| Layer | Owns | Must not own |
| --- | --- | --- |
| `ui.RenderPage` | screen padding, hero, column gap, help, pending, size guard | domain data |
| page `View` | hero strings, left/right body, help keys, pending state | lipgloss borders for buttons, local padding constants |
| page content helpers | section bodies, lists, previews | screen chrome |

### Geometry tokens (code defaults)

```text
screenPaddingX = 1 cell each side   (via Screen.Padding(1, 1))
screenPaddingY = 1 cell top/bottom
columnGap      = 2 spaces
minContentW    = 40
minContentH    = 12
leftCol hint   = clamp(width/3, 28..54) for status-machine pages
```

Wide layout: two columns when `contentW >= 90` **and** the page decides a right
pane is useful (Windows may hide the right pane while blocked/uninstalled).

Narrow layout: single column, left body then right body with one blank line.

### Startup size guard

Required on every page:

```go
if m.width <= 0 || m.height <= 0 {
    return "Initializing..."
}
```

### Hero

```text
● Title [working…] [error/message optional]
subtitle · context
```

- Status light: `●` colored by health (`ok` / `warn` / `danger` / `idle`).
- Title: `ui.Title` (bold foreground).
- Busy suffix: accent `working…` (ellipsis character `…`).
- Subtitle: one muted line; truncate to content width.
- Do not put a second free-floating status strip above the hero unless it is
  transient live feedback (e.g. voice mic level). Prefer folding into subtitle
  or help.

Shared API:

```go
ui.Hero(title, subtitle, ui.HeroOpts{
    Tone:    ui.ToneOK, // or Warn, Danger, Idle
    Busy:    busy,
    Message: errOrMsg, // optional short right/context note
})
```

### Help bar

- Always the last fixed row(s) of the page.
- Built only from `ui.HelpItem(key, label)` + `ui.HelpText(...)`.
- Labels lowercase (`apply`, `quit`, `refresh`), keys underlined accent.
- Confirm modes replace the entire help bar (`y confirm …  n/esc cancel`).

### Pending bar (draft pages only)

Used when a page has Apply/Discard drafts (keyboard remap today; others only if
they gain transactional edits):

```text
Pending changes · Apply (a) · Discard (x)
```

- Accent text, one line under help.
- Hidden when no pending changes.
- Do not invent a second checkbox-style Apply UI.

### Shared render entry

```go
ui.RenderPage(ui.Page{
    Width:   m.width,
    Height:  m.height,
    Hero:    ui.Hero(...),
    Left:    leftBody,
    Right:   rightBody, // "" = single column
    Wide:    contentW >= 90 && rightUseful,
    Help:    []string{ui.HelpItem(...), ...},
    Pending: pendingLine, // "" if none
})
```

`RenderPage` applies `FitBlock`, `PreserveBackground`, and `Screen` padding.

---

## Control Language (four primitives)

Pages may use only these interactive text controls for ordinary UI. Domain
widgets (theme color tiles, wallpaper preview, visual key picker, keycap chips)
are exceptions listed later.

### 1. Primary CTA — at most one per page state

```text
→ Connect (enter)
→ Setup voice input (enter)
→ Install Windows (enter)
```

- Accent + bold when enabled.
- Muted when disabled/busy.
- Prefix `→ ` when enabled, two spaces when disabled.
- Trailing `(enter)` or the real primary key.
- **No border.**

```go
ui.PrimaryLine(label, "enter", enabled)
```

### 2. Secondary action — plain mnemonic line

```text
Setup keyd (s)
Key Tester (t)
Refresh (r)
Diagnose (d)
```

- Normal text when enabled; subtle when disabled.
- Key in parentheses, or underline mnemonic via `ui.ActionText` when the key is
  a single letter inside the label.
- **No border, no background chip.**

```go
ui.ActionLine(key, label, enabled)
// or with underline mnemonic:
ui.ActionMnemonic(icon, key, label, enabled) // icon optional, usually ""
```

Danger secondaries (remove/delete) use danger foreground for the label only
when armed/enabled; still no border.

### 3. Toggle — checkbox row

```text
[X] Swap Left Alt / Win
[ ] Caps to Esc
```

- Focused: accent bold (enabled profile) or muted underline (disabled parent).
- Inactive profile: entire row subtle.
- Optional trailing value: `  left` in accent (override target), not a button.

```go
ui.ToggleLine(on, label, ui.ToggleOpts{Focused: true, Dimmed: false, Trailing: "left"})
```

### 4. Cycle / enum — inline value, not a boxed button

```text
Fn Row Mode: auto (f)
Wallpaper: file · folder · color
Effects: 1 performance  2 balanced  3 visuals
```

- Current value accent.
- Alternate options muted.
- Cycle key shown as `(f)` or as underlined mnemonic; **never**
  `ActionButton("< auto >")` with a NormalBorder box.

```go
ui.CycleLine(label, value, key, focused)
ui.SegmentedLine(label, options, selected, keys)
```

### Explicitly forbidden as default controls

| Pattern | Why |
| --- | --- |
| `ui.Button` / `ActionButton` NormalBorder boxes for Setup/Refresh/etc. | Visual noise; breaks series look |
| Status pills with full box borders for “keyd: active” | Use status light + text |
| Full-row reverse video selection as the only list focus | Prefer cursor marker |
| Local `sectionTitle` redefinitions with accent | Steal hierarchy from hero |
| Emoji focus bullets (`🔘`) as selection | Use `▸` / `●` / `○` consistently |

Legacy `ButtonView` / `PrimaryButtonView` remain only for true modal chrome if
needed; new page code must not call them for ordinary actions.

---

## Section Headers

```go
ui.SectionTitle("Connected keyboards")
```

Rules:

- Muted, bold (existing `ui.Section` token).
- Title Case preferred in English UI strings (`Connected Keyboards`,
  `Function Row`, `Presets`). ALL CAPS is allowed only if the whole series uses
  it; default is **Title Case**.
- **Not accent-colored.** Accent section titles make the page shout.
- One blank line after a section header before content, unless packing a dense
  list.

---

## Focus And Selection Language

| Context | Idle | Focused / selected |
| --- | --- | --- |
| List row (devices, bindings) | `●` online accent / `○` offline subtle + label | `▸ ` + accent bold label |
| Toggle row | `[X]` / `[ ]` + text | same + accent bold |
| Cycle row | normal label | accent bold label |
| Theme tile | hidden border | thick border accent (domain exception) |
| Primary CTA | muted or accent line | N/A (not a list) |

Do not mix reverse-video full-width bars with `▸` markers on the same page.
Keyboard device list must use the list-row rules above.

Online/offline is independent of focus:

```text
▸ minila r convertible keyboard     ← focused + connected
● apple spi keyboard                ← connected
○ guo magic keyboard (offline)      ← offline
```

---

## Borders And Surfaces

Borders are **surface** chrome, not control chrome.

| Allowed bordered surface | Border style | Examples |
| --- | --- | --- |
| Card / model summary | Thick or rounded, accent or line | Voice model card, optional status card |
| Preview | Thick, soft line | Wallpaper preview |
| Modal overlay | Rounded, line | Keyboard target key picker |
| Selected grid tile | Thick, accent | Theme swatch selected |

| Disallowed | |
| --- | --- |
| Border around secondary actions | |
| Border around cycle values | |
| Border around every section | |
| Nested panel boxes inside both columns by default | Prefer flat columns on the page background |

Column panels do **not** need `PanelBox` wrappers by default. Windows/Voice
already look cleaner without double frames. Use a single thick card only when
the content is a true “spec card” (e.g. model specifications).

---

## Status Light Tones

Shared helper:

```go
ui.StatusDot(ui.ToneOK)    // accent
ui.StatusDot(ui.ToneWarn)  // warn
ui.StatusDot(ui.ToneDanger)// danger
ui.StatusDot(ui.ToneIdle)  // subtle
```

| Tone | When |
| --- | --- |
| OK | Ready / healthy / keyd running / model ready |
| Warn | Booting / downloading / degraded |
| Danger | Blocked / error / failed |
| Idle | Stopped / inactive / unknown |

---

## Help And Key Label Style

- `ui.HelpItem("enter", "connect")` — key underlined accent, label lowercase muted.
- Join with two spaces via `ui.HelpText`.
- Page-specific keys stay page-local; framing is shared.
- Prefer short verbs: `apply`, `quit`, `refresh`, `setup keyd`, not sentences.

---

## Per-Page Mapping

All four pages use the same shell. Content columns follow existing IA docs.

### Theme (`theme`)

```text
Hero: ● Theme & Appearance
      current · N themes · wallpaper mode summary
Left:  theme grid (domain tiles OK)
Right: wallpaper preview (bordered surface OK)
       mode cycle (file / folder / color) — Cycle/Segmented, no boxes
       folder controls as ActionLines
       effects as SegmentedLine or ActionLines 1/2/3
```

Immediate apply; no pending bar.

### Voice (`voice`)

```text
Hero: ● Voice Input
      health · model · daemon
Left:  model card (one bordered surface OK)
       triggers (keycap chips OK as domain widget)
       primary/secondary actions as text lines
Right: logs / progress / get started
```

Immediate apply; confirm bar replaces help when deleting model.

### Keyboard (`keyboard`)

```text
Hero: ● Keyboard Remap
      keyd active/inactive · N devices · pending count optional
Left:  Connected Keyboards (list focus language)
       Actions: Setup keyd (s), Key Tester (t) as ActionLines
Right: Keyboard Profile (device name, id)
       [X] Profile Enabled
       Function Row: CycleLine for fnmode
       Presets as ToggleLines with optional trailing remap target
Pending: when drafts exist
Modal: visual key picker remains bordered overlay
```

### Windows VM (`windows`)

```text
Hero: ● Windows VM
      state subtitle
Left:  state-specific body + PrimaryLine + ActionLines
Right: connection / logs when showSidePanel()
```

Already closest to the target; rehome onto `RenderPage` and shared action lines.

---

## Shared Package Layout

```text
tui-go/internal/ui/
├── theme.go      colors, Screen, Title, Section, text styles, InitTheme
├── layout.go     FitBlock, PreserveBackground, Truncate*, WrapStyled, Row
├── text.go       ShortPath, ProgressBar, FormatDuration
├── shell.go      Page, Hero, RenderPage, StatusDot, SectionTitle  (new)
└── controls.go   PrimaryLine, ActionLine, ToggleLine, CycleLine,  (new)
                  ListItem, SegmentedLine, PendingLine
```

Pages delete local copies of:

- `sectionTitle`
- `actionPrimary` / `actionSecondary` (replace with ui helpers)
- bordered `button()` used for ordinary actions
- private full palettes that duplicate `ui.*` colors (use `ui.Accent` etc.)

Domain-only helpers may remain in the page package (image preview, key picker
grid, theme tiles, keycap chips).

---

## Migration Checklist

For each page:

1. `View()` calls `ui.RenderPage` (or returns only a modal overlay full-screen).
2. Size guard present.
3. Hero uses `ui.Hero` / `ui.StatusDot`.
4. Sections use `ui.SectionTitle` (muted).
5. Primary/secondary actions use text primitives; no NormalBorder action boxes.
6. Lists use `▸` / `●` / `○` focus language.
7. Help built from `HelpItem` / `HelpText`.
8. Pending only via `PendingLine` when applicable.
9. No page-local redefinition of accent section headers for normal sections.
10. `go test ./...` under `tui-go` passes.

Order of migration:

1. Shared `ui` shell + controls (this contract in code)
2. Keyboard (largest visual debt)
3. Theme (bordered action buttons)
4. Voice + Windows (rehome to shell; delete duplicates)

---

## Review Checklist (PR / agent)

```sh
# No page-local bordered action buttons for ordinary controls
rg -n 'Border\(lipgloss\.(Normal|Rounded)Border\(\)' tui-go/internal/pages -g '*.go'

# Prefer shared helpers
rg -n 'func \(m Model\) (sectionTitle|actionPrimary|actionSecondary|button)\b' tui-go/internal/pages -g '*.go'

# All pages should render through shell (or document exception)
rg -n 'RenderPage|Initializing\.\.\.' tui-go/internal/pages -g '*.go'

cd tui-go && go test ./...
```

Allowed remaining borders: theme tiles, wallpaper preview, voice model card,
keyboard picker modal, and any future true surface card.

---

## Non-Goals

- Unifying QML Settings Center widgets (separate `TuiStyle` / SettingsTokens).
- Changing backend CLI contracts or keyd/voice/vm behavior.
- Forcing identical left/right content across domains.
- Mouse hit-testing redesign (existing mouse handlers may stay; coordinates
  must track the shared shell geometry).

---

## Success Criteria

A user opening theme → voice → keyboard → windows in sequence should perceive:

1. Same window padding and title treatment
2. Same help bar grammar
3. Same action density (text lines, not boxed buttons)
4. Same list focus cursor
5. Same section quietness (muted headers, accent on focus/CTA only)

If any page still “feels like a different app,” the shell or control language
was bypassed.
