# Bar Status Popup — Height Stability & Flash

Why volume / display (and similar) bar popups flash when their content height
changes, and how Sumika Shell avoids that flash.

Related code:

- `quickshell/modules/bar/BarStatusPopup.qml`
- `quickshell/modules/common/widgets/TuiShell.qml`
- `quickshell/modules/common/widgets/StyledRectangularShadow.qml`

---

## Symptom

Panels such as **Volume** (device list) and **Display** (optional rows) can
change structure while open. Ideal UX:

- Unchanged rows stay visually still.
- Opening a device list does not flash or jump the whole card.

Bad approaches:

- Growing `PanelWindow` height (accordion in-flow) → whole layer-shell surface
  redraws; animating that height multiplies the flash.
- Reserving empty layout space when collapsed → stable but looks broken.

---

## Height propagation chain

Any in-flow content height change walks this path:

```text
section Layout.preferredHeight  (e.g. 0 ↔ N)
  → column / panel.implicitHeight
  → contentLoader.implicitHeight
  → TuiShell (panelBg).implicitHeight
  → panel.implicitHeight  (+ shadow margin)
  → PanelWindow.implicitHeight   ← Wayland layer-shell surface size
```

`BarStatusPopup` is top+right (or bottom+right) anchored. Geometry can keep the
**top edge** fixed while the bottom grows. The flash is usually **not** “layout
shoving the header down”; it is full-surface redraw / retarget.

---

## Root causes

| Cause | Effect |
| --- | --- |
| **Layer-shell surface resize** | Compositor resizes the whole buffer; not a partial bottom damage region. |
| **`TuiShell` `layer` + `OpacityMask`** | Rounded clip is an offscreen FBO. Size change rebuilds the mask texture → whole chrome flashes. |
| **`StyledRectangularShadow` (`cached: true`)** | Shadow cache invalidates on target resize; often one frame of misaligned shadow. |
| **Animating height up the chain** | Every animation frame resizes the surface and rebuilds layer/shadow → multi-frame jitter. |

Empty `Behavior on implicitHeight { }` on the `PanelWindow` already disables
implicit window-height animation. That only stops continuous window tweening.

---

## What works

### 1. Prefer constant geometry (best for toggles)

Display night-mode intensity keeps the slider **in the layout** and only
changes `opacity` / `enabled`. Toggling night mode must not collapse a row.

Rule: if a control is only “inactive”, fade or disable it; do **not**
`visible: false` it if that changes popup height.

### 2. Prefer always-visible structure (volume I/O)

Volume Output/Input device lists are **always expanded** in the layout — no
accordion, no overlay. Height is fixed for a given device set while the popup
is open, so there is no toggle-time surface resize.

Entry to full sound settings is a gear on the Volume `PopupHeader`
(`actionIcon: "settings"`), not a bottom footer row (saves vertical space).

If a future section truly needs collapse, prefer constant geometry or a
dedicated settings page over animating `PanelWindow` height.

### 3. Lighter shell chrome while height is dynamic

Bar status popups set `TuiStyle.useLayerMask` / `TuiShell.useLayerMask: false`
so incidental resizes (media row, etc.) do not rebuild an `OpacityMask` FBO.

### 4. Fixed height + `ScrollView`

Most stable for long always-visible lists. No accordion chrome.

---

## What to avoid

- `Behavior` / `NumberAnimation` on `Layout.preferredHeight` or any ancestor
  `implicitHeight` that feeds `PanelWindow`.
- In-flow accordion that grows the card (open or close).
- `retainHeight` empty bands under section headers (stable but ugly).
- Hide/show rows that change total height for transient toggles when a
  fade-in-place is enough.

---

## Practical ranking (Sumika Shell)

| Goal | Approach |
| --- | --- |
| Zero height change (toggles) | Opacity / enabled only (display night slider). |
| Device list without flash | Always show the list (volume) or open settings page. |
| Long lists | Cap height + scroll, or open full settings. |
| Pixel-perfect zero flash + in-flow grow | Not reliable on layer-shell. |

---

## Checklist for new expandable popup sections

1. Will this change `PanelWindow.implicitHeight` while open?
2. If yes for a list: prefer always-visible rows or a settings page, not
   animated in-flow accordion height.
3. Prefer not to use `TuiShell` layer mask on height-variable bar popups.
4. Put secondary actions (settings) in the header gear, not an extra footer.
