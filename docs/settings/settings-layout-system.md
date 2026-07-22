# Settings Panel Layout System

OMD settings panels share one layout contract. Feature pages provide content;
the settings shell owns window padding, scrolling, the footer, and global
control geometry. This keeps independent settings panels visually consistent
without copying margins into every page.

## Ownership

```text
SettingsDialog.qml
└── window dimensions and shared shell/page insets
    └── SettingsPanelFrame.qml
        ├── clipped scrolling viewport
        ├── page placement
        └── footer placement and action alignment
            └── feature page
                ├── responsive columns
                ├── cards and sections
                └── feature-specific controls
```

`SettingsTokens.qml` is the single source of truth for shared geometry and
colors. A feature page must not compensate for shell spacing with values such
as `pageInset + 4`, asymmetric footer margins, or a locally duplicated
42-pixel button height.

`SettingsPanelFrame.qml` sizes every loaded page to at least the available
scroll viewport. Short pages therefore fill the area above the footer instead
of leaving a black gap, while tall pages retain their implicit height and
scroll normally.

## Layout Tokens

The shared geometry currently includes:

| Token | Purpose |
| --- | --- |
| `shellInset` | Gap between the dialog border and its internal shell |
| `pagePadding` | Page and footer horizontal alignment line |
| `panelPadding` | Padding inside a major content card |
| `columnGap` | Space between responsive page columns |
| `sectionGap` | Vertical space between major sections inside a card |
| `controlGap` | Space between adjacent controls and buttons |
| `controlHeight` | Standard button/control height |
| `footerBalanceOffset` | Centers footer buttons across the frame inset |
| `footerHeight` | Control height, lower page padding, and frame balance |
| `footerButtonWidth` | Standard Discard/Apply button width |
| `footerCloseButtonWidth` | Close button width |

Change these tokens before editing several feature files. A new token is
appropriate when the value describes a repeated layout role. Feature-specific
dimensions, such as the monitor canvas preview height, remain in the feature.

## Footer Contract

`SettingsPanelFrame.qml` owns the footer. Pages expose state and operations:

```qml
readonly property bool hasPendingChanges: state.hasPendingChanges
readonly property bool applying: state.applying
function resetDrafts() { state.resetDrafts() }
function applyAll() { state.applyAll() }
```

The frame renders Close on the left and Discard/Apply on the right. All three
buttons use `SettingsButton` and the same `controlHeight`. The content viewport
already contributes `pagePadding` above the buttons. The button row is pinned
to the top of the footer. Its remaining height combines one `pagePadding` with
`footerBalanceOffset`, which accounts for the shell inset around the frame and
keeps the visible upper and lower gaps equal. The footer's left and right edges
also use exactly `pagePadding`, matching the content viewport above.

Do not add a second action footer inside a feature page. Immediate actions that
do not participate in the page transaction, such as Identify Displays or
Detect Displays, belong near the content they affect and should use
`ButtonRow` plus `SettingsButton`.

## Displays Reference Layout

The Displays page is the reference implementation for wide master-detail
settings panels:

```text
pagePadding
├── left panel (panelPadding)
│   ├── section heading
│   ├── monitor canvas
│   ├── ButtonRow
│   └── output list
├── columnGap
└── right panel (panelPadding)
    ├── selected-output summary
    ├── display mode
    ├── scale
    └── advanced controls

footer
├── Close
└── Discard / Apply
```

At narrow widths, the two panels become one column while preserving
`columnGap`, `panelPadding`, and footer alignment.

## Voice Reference Layout

The Voice page reuses the same wide master–detail contract without a canvas:

```text
pagePadding
├── left panel (panelPadding)
│   ├── health hero
│   ├── trial record + last result
│   └── recent history
├── columnGap
└── right panel (panelPadding)
    ├── keybindings
    ├── model / engine actions
    └── advanced disclosure (paths, TUI tools)

footer
└── Close
```

Implementation details: [`../features/voice-input.md`](../features/voice-input.md).

## Windows VM Reference Layout

```text
pagePadding
├── left panel (panelPadding)
│   ├── health hero
│   ├── primary CTA (install / fix / connect)
│   └── install progress (when active)
├── columnGap
└── right panel (panelPadding)
    ├── connection (web / RDP / start-stop)
    ├── specs
    └── advanced (requirements, paths, logs, remove)

footer
└── Close
```

The Windows VM page follows this shared layout contract; feature behavior stays
in its page and backend instead of a separate layout specification.

## Appearance Reference Layout

```text
pagePadding
├── left panel · Themes
│   ├── current theme hero + swatches
│   └── available theme grid
├── columnGap
└── right panel · Desktop & terminal
    ├── wallpaper
    ├── terminal font
    └── window effects

footer
└── Close
```

Wallpaper runtime behavior is documented in
[`../architecture/wallpaper-runtime.md`](../architecture/wallpaper-runtime.md).

## Keyboard Remap Reference Layout

```text
pagePadding
├── left panel · Status & keyboards
│   ├── health hero
│   ├── service actions
│   └── device list
├── columnGap
└── right panel · Selected keyboard
    ├── enable toggle
    ├── presets
    └── apply confirm (when armed)

footer
├── Close
└── Discard / Apply  (when drafts pending)
```

Keyboard behavior is documented in
[`../features/keyboard-remap.md`](../features/keyboard-remap.md).

## Network Reference Layout

```text
pagePadding
├── left panel · Connect
│   ├── hero + Wi-Fi radio
│   ├── available networks
│   └── saved profiles
├── columnGap
└── right panel · Link & tools
    ├── current link (IP/DNS/band/rates)
    ├── diagnostics
    ├── suggested Wi-Fi
    └── advanced (firewall, nm tools)

footer
└── Close
```

Connect protocol: [`../features/wifi-connect-flow.md`](../features/wifi-connect-flow.md).

## Slider Rows

`SettingsSliderRow` uses a stacked layout: the label and optional description
form the first row, then the slider uses the full available width on the next
row with a fixed-width value label at the right. Do not place a short slider
beside the title text. Device-specific volume rows should follow the same
structure even when they also include a selection indicator or edit action.

## Page Rules

1. Use `SettingsTokens.panelPadding` for major card interiors.
2. Use `SettingsTokens.columnGap` between top-level columns.
3. Use `SettingsTokens.sectionGap` between semantic sections.
4. Use `ButtonRow` for equal-height adjacent actions.
5. Use `SettingsButton`; do not restate its standard height locally.
6. Keep transaction actions in the shared footer.
7. Keep feature-specific rendering and state out of `SettingsPanelFrame.qml`.
8. Verify wide and narrow layouts after changing global geometry tokens.
9. Keep continuous controls wide by placing their sliders below their labels.

## Verification

Open a panel through the real cold-start entry point:

```sh
~/.config/omd/bin/omd-settings open display
```

Check that:

- left and right content cards share top and bottom edges;
- content and footer buttons share horizontal alignment lines;
- all footer buttons share one vertical center and height;
- visual space above and below the footer buttons is equal;
- adjacent action buttons use the same gap and height;
- no QML errors appear in `/tmp/omd-settings.log`.
