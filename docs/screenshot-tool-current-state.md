# Screenshot Architecture

Updated: 2026-07-16

## Goals

OMD has two screenshot paths with deliberately different priorities:

- Fast capture must open immediately and keep pointer selection smooth.
- Capture and edit must freeze the desktop before the selector takes focus, so
  bar menus, popups, notifications, and other overlays can be included.
- Multi-monitor work is scoped to the Hyprland focused monitor. The screenshot
  tool does not create a selector or decode a frozen image on every output.
- Screenshot UI remains cold-started and consumes no memory while inactive.

## User-facing bindings

| Entry | Mode | Implementation |
| --- | --- | --- |
| `Alt+S` | Fast region capture | `slurp -> grim -> wl-copy` |
| `Print` | Fast region capture | `slurp -> grim -> wl-copy` |
| `Alt+Shift+S` | Frozen capture and edit | focused-output `grim` snapshot -> QML selector -> ImageMagick crop -> editor |
| Bar `Capture Area` | Fast region capture | `bin/omd-screenshot screenshot` |
| Bar `Capture & Edit` | Frozen capture and edit | `bin/omd-screenshot edit` |

Pressing the same fast-capture shortcut while `slurp` is open cancels it.

## Fast path

`bin/omd-screenshot screenshot` does not launch Quickshell and does not capture
the desktop before selection:

1. Record the currently focused Hyprland output.
2. Run `slurp` and obtain geometry plus the output containing the selection.
3. Reject a selection started on a different output and crop geometry at the
   focused output boundary.
4. Capture only the selected geometry with `grim`.
5. Copy the PNG to the clipboard with `wl-copy`.
6. If `screenSnip.savePath` is configured, save a timestamped copy there.

This is the default path because `slurp` is a small native layer-shell client.
It avoids Quickshell startup, full-output PNG compression, image decoding, and
QML pointer-frame rendering.

## Frozen edit path

`bin/omd-screenshot edit` preserves the snapshot-first behavior:

1. Resolve the focused monitor with `hyprctl monitors -j`.
2. Tell `omd-bar` that screenshot capture has begun, keeping visible overlays
   alive long enough to be captured.
3. Capture only that monitor to a temporary PNG.
4. Export `OMD_SCREENSHOT_MONITOR` and its snapshot path.
5. Cold-start `apps/omd-screenshot`.
6. `RegionSelector.qml` creates exactly one `RegionSelection`, for that output.
7. The selected area is cropped from the frozen PNG and passed to the existing
   post-capture actions.

The QML path remains appropriate for frozen overlays, window targeting, square
or circular selection, recording, and the post-capture action bar. It is not
used for ordinary clipboard screenshots.

## Pointer rendering rules

The QML selector must keep its pointer hot path small:

- Window/layer target detection runs only while hovering, not while dragging.
- Pointer history is collected only for circle selection.
- The moving crosshair uses plain rectangles, not `MultiEffect` layers.
- The darkened outside area uses four rectangles rather than a screen-sized
  synthetic border.

New effects or model updates must not be bound directly to every pointer event
without measuring their frame cost.

## Shared action entry points

The bar menu, keyboard bindings, and Screenshot Toolbox call
`bin/omd-screenshot`; they must not implement separate region-copy or edit
pipelines. The toolbox may keep specialized external actions such as OCR,
measurement, QR decoding, pinning, and annotation, but ordinary capture and
capture-and-edit use the shared backend.

## Dependencies

Required for the primary paths:

- `grim`
- `slurp`
- `wl-copy`
- `jq`
- ImageMagick (`magick`) for frozen snapshot cropping
- the configured annotation editor (`swappy` or `satty`)

Optional toolbox actions may additionally require `tesseract`, `hyprpicker`,
`mark-shot`, `qt-img-viewer`, or `zbarimg`. Missing optional tools must not
break fast capture or frozen editing.

## Relevant files

- `bin/omd-screenshot`: shared launcher and capture backend
- `apps/omd-screenshot/shell.qml`: cold-start QML process
- `quickshell/modules/regionSelector/RegionSelector.qml`: target-output scope
- `quickshell/modules/regionSelector/RegionSelection.qml`: selection behavior
- `quickshell/modules/common/utils/ScreenshotAction.qml`: post-capture actions
- `apps/omd-shot-toolbox/`: optional action toolbox
- `hypr/bindings.lua`: `Alt+S` and `Alt+Shift+S`
- `hypr/default/hypr/bindings/utilities.lua`: Print Screen bindings
