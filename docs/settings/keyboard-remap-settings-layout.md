# Keyboard Remap Settings Layout

Date: 2026-07-15

## Goal

Align Keyboard Remap with the shared two-column settings pattern:

- left: **health + keyboard list**
- right: **selected keyboard presets**
- footer: **Discard / Apply** when drafts are pending (same as Displays)

## Target Layout

```text
wide (≥980)
├── left · Status & keyboards
│   ├── hero (keyd ready / pending / N devices)
│   ├── setup / recheck
│   └── device list (connected · saved)
└── right · Selected keyboard
    ├── back/remove (narrow only for back)
    ├── enable toggle
    ├── presets with edit + toggle
    └── apply confirm (when armed)

footer: Close · Discard · Apply
```

## Behavior

- Selecting a device shows its presets on the right (no full-page swap on wide).
- Narrow: list first; open detail with chevron; Back returns to list.
- Footer `hasPendingChanges` / `applyAll` / `resetDrafts` bind to `KeyboardRemap`.
- Apply may still open an in-page confirm before writing `/etc/keyd/omd.conf`.
- File: `quickshell/modules/settings/pages/KeyboardRemapPage.qml`
- Overlay: `KeyboardEditorOverlay.qml` unchanged ownership.
