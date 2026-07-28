# Screenshot Architecture

## Goals

Sumika Shell has two screenshot paths with deliberately different priorities:

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
| Bar `Capture Area` | Fast region capture | `bin/sumika-screenshot screenshot` |
| Bar `Capture & Edit` | Frozen capture and edit | `bin/sumika-screenshot edit` |

Pressing the same fast-capture shortcut while `slurp` is open cancels it.

## Fast path

`bin/sumika-screenshot screenshot` does not launch Quickshell and does not capture
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

`bin/sumika-screenshot edit` preserves the snapshot-first behavior:

1. Resolve the focused monitor with `hyprctl monitors -j`.
2. Tell `sumika-bar` that screenshot capture has begun, keeping visible overlays
   alive long enough to be captured.
3. Capture only that monitor to a temporary PNG.
4. Export `SUMIKA_SCREENSHOT_MONITOR` and its snapshot path.
5. Cold-start `apps/sumika-screenshot`.
6. `RegionSelector.qml` creates exactly one `RegionSelection`, for that output.
7. The selected area is cropped from the frozen PNG and passed to the existing
   post-capture actions.

The QML path remains appropriate for frozen overlays, window targeting, square
or circular selection, recording, and the post-capture action bar. It is not
used for ordinary clipboard screenshots.

## Architecture overview

```
bin/sumika-screenshot                    # Shell entry point — dispatches to fast or frozen path
  ├── screenshot                      # → fast_capture(): slurp → grim → wl-copy
  └── edit|search|ocr|record          # → launch_direct(): grim snapshot → Quickshell

apps/sumika-screenshot/shell.qml         # Cold-start QML process
  └── RegionSelector {}               # Module entry point

quickshell/modules/regionSelector/     # Region selector QML modules
  ├── RegionSelector.qml              # Parse target monitor, create RegionSelection per screen
  ├── RegionSelection.qml             # Core: frozen snapshot display, selection interaction,
  │                                   #        snip/crop pipeline, post-phase action bar
  ├── RectCornersSelectionDetails.qml # Rectangle overlay: darken overlay + dashed border
  │                                   #   + dimension label + aim crosshairs
  ├── CircleSelectionDetails.qml      # Circle overlay: ShapePath with stroke
  ├── TargetRegion.qml                # Window/layer/content region highlight box
  ├── CursorGuide.qml                 # Crosshair cursor indicator at drag corner
  ├── OptionsToolbar.qml              # Rectangle/Circle mode toggle
  └── RegionFunctions.qml             # IoU calculation, window/layer overlap filtering

quickshell/modules/common/utils/
  └── ScreenshotAction.qml            # Post-capture command builder — crops from frozen
                                      #   snapshot and dispatches Copy/Edit/Search/OCR/Record
```

## Frozen edit flow detail

### Pre-capture (shell side)

1. `bin/sumika-screenshot` acquires a `flock` lock to serialize rapid clicks.
2. Re-launch while already open = cancel (same mental model as `slurp` toggle).
3. Touch `/tmp/sumika-screenshot-active` and send IPC `screenshot begin` to bar.
4. Snapshot the focused monitor with `grim -o <monitor> <snapshot_dir>/snapshot-<monitor>-<ts>.png`.
5. Export `SUMIKA_SNAPSHOT_PATH_<MONITOR_ENV>` with the snapshot path.
6. Launch `apps/sumika-screenshot` as a detached `qs` process.

### Snapshot loading (QML side)

1. `RegionSelection.qml` checks for `SUMIKA_SNAPSHOT_PATH_*` pre-captured files.
2. If pre-captured snapshot exists → use it directly (`preCapSnapshot = true`).
   The shell script captures before QS starts, so bar popups/menus are frozen
   in the image.
3. If no pre-captured snapshot → fall back to `snapshotProc` which runs
   `grim -o <screen>` after QML has initialized.
4. Set `closeMenusOnShow = true` → after the overlay becomes visible, send IPC
   `menus close` to the bar. This ordering prevents the user from seeing a
   frame where live menus have disappeared but the frozen overlay hasn't
   appeared yet.
5. Display the frozen snapshot as an `Image` filling the full `PanelWindow`.

### Selection interaction

1. `MouseArea` covers the entire screen; cursor hidden during selection.
2. Hover (no drag): detect window/layer regions under cursor via
   `targetedRegion` logic. Hovered region gets a highlight border.
3. Click (no drag): if cursor is over a detected region, snap selection to
   that region's boundaries.
4. Drag: update `dragStartX/Y` → `draggingX/Y` → compute `regionX/Y/Width/Height`.
   - Normal drag: rectangular region from start to current cursor.
   - Shift+drag: constrain to square.
   - Circle mode: collect `points[]` for `ShapePath`.
5. Release: detect click-vs-drag; if drag, finalize region; for circle,
   compute bounding box of all points with padding.
6. Four `Rectangle` elements create the dark overlay outside the selection
   region (no expensive pixel-level compositing).

### Snip / crop pipeline

```
snip()
  ├─ Validate region bounds (non-zero, clamp to screen)
  ├─ Adjust action: Right-click → Edit
  ├─ snipDelayTimer (100ms)
  │
  ├─ [Edit mode]
  │   └─ postCaptureProc: magick -crop <region> snapshot.png temp.png
  │      └─ onExited → postCaptureReady = true
  │         └─ Phase.Post → show action bar
  │
  └─ [Other modes: Copy, Search, OCR, Record]
      └─ ScreenshotAction.getCommand(): crop from frozen snapshot +
         execute action script
         └─ dismiss()
```

### Post-phase action bar (Edit mode only)

After cropping, a semi-transparent overlay with 4 action buttons appears:

| Icon | Action | Command |
|------|--------|---------|
| `content_copy` | Copy cropped image to clipboard | `wl-copy` |
| `save` | Save to configured directory + clipboard | `tee` → save + `wl-copy` |
| `image_search` | Upload to image search engine | `curl` → upload → `xdg-open` |
| `edit` | Open in annotation editor | `swappy` / `satty` |
| `text_snippet` | OCR text recognition | `paddleocr` → extract text → `wl-copy` |

The post-phase bar also captures clicks outside the buttons via a full-screen
`MouseArea` to dismiss.

## OCR integration (PaddleOCR)

The OCR action replaces the legacy `tesseract` pipeline with PaddleOCR
(https://github.com/PaddlePaddle/PaddleOCR), which provides:

- PP-OCRv6 models with strong Chinese, English, and Japanese recognition
- Rotated and vertical text support
- Layout analysis and table recognition
- Efficient CPU inference

**Command pipeline:**
```bash
paddleocr ocr -i <crop.png> --lang ch 2>/dev/null \
  | python3 -c "import sys,json; print('\n'.join(r[1][0] for r in json.load(sys.stdin)))" \
  | wl-copy
```

**Availability:**
- The `paddleocr` CLI is provided by the `paddleocr` Python package.
- Installation: `pip install paddleocr`
- If `paddleocr` is not installed, the OCR button in the action bar still
  appears but the command will fail silently. Missing optional tools must
  not break fast capture or frozen editing.

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
`bin/sumika-screenshot`; they must not implement separate region-copy or edit
pipelines. The toolbox may keep specialized external actions such as
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

Optional for OCR:

- `paddleocr` (Python package, `pip install paddleocr`)

Optional toolbox actions may additionally require `hyprpicker`, `mark-shot`,
`qt-img-viewer`, or `zbarimg`. Missing optional tools must not break fast
capture or frozen editing.

## Relevant files

- `bin/sumika-screenshot`: shared launcher and capture backend
- `apps/sumika-screenshot/shell.qml`: cold-start QML process
- `quickshell/modules/regionSelector/RegionSelector.qml`: target-output scope
- `quickshell/modules/regionSelector/RegionSelection.qml`: selection behavior
- `quickshell/modules/regionSelector/RectCornersSelectionDetails.qml`: rectangle overlay rendering
- `quickshell/modules/regionSelector/CircleSelectionDetails.qml`: circle overlay rendering
- `quickshell/modules/regionSelector/TargetRegion.qml`: window/layer highlight boxes
- `quickshell/modules/regionSelector/CursorGuide.qml`: drag corner crosshair
- `quickshell/modules/regionSelector/RegionFunctions.qml`: IoU utility functions
- `quickshell/modules/common/utils/ScreenshotAction.qml`: post-capture commands
- `apps/sumika-shot-toolbox/`: optional action toolbox
- `hypr/bindings.lua`: `Alt+S` and `Alt+Shift+S`
- `hypr/default/hypr/bindings/utilities.lua`: Print Screen bindings
