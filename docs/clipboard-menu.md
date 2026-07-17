# Clipboard Menu

## Goal

The clipboard UI is a lightweight, on-demand menu inspired by Maccy rather
than a persistent settings-style dialog. `Alt+V` opens it at the current
pointer position on the pointer's monitor.

The UI has three parts:

- a search field at the top;
- a compact list of recent text and image entries;
- a delayed detail preview beside the menu while an entry is hovered.

The detail preview opens on the right when space is available and moves to the
left near the screen edge. The menu itself is clamped to the current screen.

## Runtime Structure

- `apps/omd-clipboard/shell.qml` owns the overlay window. It reads
  `hyprctl cursorpos -j` and `hyprctl monitors -j`, selects the matching
  Quickshell screen, and only then shows the menu.
- `apps/omd-clipboard/modules/clipboard/ClipboardDialog.qml` owns search,
  keyboard navigation, menu placement, and the side preview.
- `apps/omd-clipboard/modules/clipboard/widgets/ClipboardItem.qml` renders one
  compact text or image menu row.
- `apps/omd-clipboard/services/Cliphist.qml` remains the data and action layer.
  UI code must not reimplement cliphist decoding or paste commands.

The process remains cold-started through `bin/omd-clipboard` and exits when the
menu closes.

## Interaction

- Type to filter immediately.
- `Up` / `Down`: change the selected entry.
- `Enter`: paste the selected entry.
- `Ctrl+Enter`: for an image, decode it to a temporary file and paste its path.
- `Shift+Delete`: delete the selected entry.
- `Escape`: close the menu.
- Clicking `Clear history` wipes cliphist history.
- Drag the top search/header area to move the menu temporarily when it covers
  nearby content. The position is not persisted; the next open starts at the
  current pointer position again.

Mouse hover updates selection and opens the detail preview after a short delay.
Clicking a row pastes it. Image rows expose a folder action for path paste.

## Image Path Paste Contract

The existing image-to-path behavior is intentionally preserved. Calling
`Cliphist.pasteImagePath(entry)`:

1. decodes the image to `/tmp/omd-clip-<timestamp>.png`;
2. writes that path plus a trailing space to the clipboard;
3. simulates paste into the previously focused application.

Do not replace this with ordinary image paste. Both actions are useful:
clicking the row pastes image data, while the row action or `Ctrl+Enter` pastes
the generated file path.

## Performance Rules

- Keep the process on demand; do not add it to the persistent Quickshell apps.
- Decode only visible image thumbnails and the currently hovered preview.
- Keep preview decoding delayed so pointer movement across the list does not
  launch a process for every transient row.
- Refresh is driven solely by `cliphistService update` IPC from
  `bin/omd-clipboard-store` (the `wl-paste --watch` layer). Do not add a
  `Quickshell.onClipboardTextChanged` listener — it fires for our own
  `/tmp/omd-clip-*` path writes and causes redundant refreshes.
- History is capped at 40 entries (`Cliphist.maxEntries`).
