# Keyboard Remap Settings TUI Design

## Goal

Provide a Go-based Bubble Tea TUI page for the Keyboard Remap settings under oh-my-desktop. This page is routed via `omd-settings-tui keyboard`. It manages per-keyboard profiles, toggles predefined presets, and allows overriding customizable target keys using a visual interactive 108-key layout.

## Layout & Structure

The screen follows the unified settings panel layout rules (two-column layout with status bar and footer):

```text
┌────────────────────────────────────────────────────────┐
│ ● Keyboard Remap  [ status: keyd-ready ]               │
├────────────────────────────────────────────────────────┤
│ Connected Keyboards         Selected Profile: Keyboard │
│ ───────────────────         ────────────────────────── │
│ 🔘 minila-r-convertible     Profile: [X] Enabled       │
│ ○ apple-spi-keyboard        Presets:                   │
│ ○ guo-magic-keyboard        [X] Swap Left Alt / Win    │
│                             [ ] Swap Ctrl / Caps       │
│                             [X] Muhenkan → Custom [f13]│
│                                                        │
├────────────────────────────────────────────────────────┤
│ Tab: columns | Space: toggle | Enter: pick key | a: apply│
└────────────────────────────────────────────────────────┘
```

- **Left Column**:
  - Keyd daemon status check (`keyd-ready` or `inactive`).
  - Action button: `○ Setup keyd (s)` to install/verify the daemon (runs `omarchy-keyboard-setup`).
  - List of detected keyboards, populated from `/home/tetsuya/development/OMD/keyboard-remap/profiles.json` and `omarchy-keyboard-list`.
- **Right Column**:
  - `Profile Enabled` checkbox toggle.
  - Presets list: Checkbox list to toggle presets.
  - For customizable presets (e.g. `muhenkan-meta`), displays the active target override (e.g. `[ f13 ]`). Pressing Enter on it triggers the Visual Keyboard Picker modal overlay.

---

## Visual Keyboard Picker Modal

When overriding a preset target key, a modal overlay appears in the center of the terminal rendering a complete standard keyboard:

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│                              Select Target Key                               │
├──────────────────────────────────────────────────────────────────────────────┤
│ Esc F1 F2 F3 F4   F5 F6 F7 F8   F9 F10 F11 F12                               │
│ ` 1 2 3 4 5 6 7 8 9 0 - = BkSp      Ins Hom PgU   Num / * -                  │
│ Tab Q W E R T Y U I O P [ ] \       Del End PgD   7   8   9   +              │
│ Caps A S D F G H J K L ; ' Enter                  4   5   6                  │
│ Shift Z X C V B N M , . / Shift        ▲          1   2   3   Ent            │
│ Ctrl Win Alt [      Space      ]       ◀  ▼  ▶    0     .   Del              │
│                                                                              │
│ Virtual Extended Keys:                                                       │
│ F13 F14 F15 F16 F17 F18 F19 F20 F21 F22 F23 F24                              │
├──────────────────────────────────────────────────────────────────────────────┤
│ arrows: move selector | Enter/Space: confirm key | Esc: close without save   │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Aesthetic Rules (Clean TUI style)
- **Normal keys**: `pal.surfaceContainer`, text `pal.text`.
- **Selected cursor**: inverted colors (`pal.accent` background, `pal.background` text) for high visibility.
- **Extended Keys**: An additional row at the bottom exposing `F13` through `F24`, which are highly useful for virtual remapping targets.

---

## Inter-Process Communication (Backend commands)

- **List connected devices**:
  Reads from `share/bin/omarchy-keyboard-list` or parses `keyboard-remap/profiles.json`.
- **Setup daemon**:
  Runs `share/bin/omarchy-keyboard-setup` when the user presses `s` (in a subshell redirecting stdin to `/dev/null`).
- **Apply Remaps**:
  Runs `share/bin/omarchy-keyboard-apply` to compile `profiles.json` into `/etc/keyd/omd.conf` and reload keyd.
- **Status Change Check**:
  Compares the output of `share/bin/omarchy-keyboard-render` with `/etc/keyd/omd.conf` to determine if `Pending changes` are present.
