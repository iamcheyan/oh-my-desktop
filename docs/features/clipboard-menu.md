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

- `apps/sumika-clipboard/shell.qml` owns the overlay window. It probes
  `hyprctl monitors -j` (Hyprland IPC): on success it also reads
  `hyprctl cursorpos -j`, selects the matching Quickshell screen, and only
  then shows the menu at the pointer. On failure (non-Hyprland compositors
  such as labwc — no hyprctl socket, and no Wayland protocol exposes the
  absolute pointer position to clients) it falls back to `wlr-randr --json`
  for the monitor layout and anchors the menu to the bar
  (`positionMode: "bar"`) — the same fixed position as clicking the bar's
  clipboard button. The compositor is detected by probing the hyprctl
  socket, never env vars (which can be stale across session switches).
- `apps/sumika-clipboard/modules/clipboard/ClipboardDialog.qml` owns search,
  keyboard navigation, menu placement, and the side preview.
- `apps/sumika-clipboard/modules/clipboard/widgets/ClipboardItem.qml` renders one
  compact text or image menu row.
- `apps/sumika-clipboard/services/Cliphist.qml` remains the data and action layer.
  UI code must not reimplement cliphist decoding or paste commands.

The process remains cold-started through `bin/sumika-clipboard` and exits when the
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

1. decodes the image to `/tmp/sumika-clip-<timestamp>.png`;
2. writes that path plus a trailing space to the clipboard;
3. calls `sumika-paste-at-cursor auto` to paste into the previously focused
   application.

Do not call `ydotool Ctrl+V` directly from the clipboard UI. Some machines do
not run `ydotoold`, and on Japanese keyboard layouts ydotool's kernel scancode
for `V` may not resolve to the `V` keysym. The shared paste helper uses
Hyprland / wtype / ydotool fallbacks and picks terminal-specific paste actions
where needed.

Do not replace this with ordinary image paste. Both actions are useful:
clicking the row pastes image data, while the row action or `Ctrl+Enter` pastes
the generated file path.

Kitty also maps `Ctrl+V` to `bin/sumika-kitty-smart-paste`. When the clipboard
contains an image, that helper decodes it to `/tmp/sumika-clip-*`, replaces the
active Wayland clipboard payload with the generated path, and sends the same
path to Kitty as bracketed paste. Keeping both payloads identical is required
for image-aware terminal applications such as OpenCode: if the clipboard is
left as an image while the terminal receives a path, OpenCode imports both and
shows the image twice (`sumika-clip-*.png` plus `clipboard`). The original image
remains available in cliphist history.

## Performance Rules

- Keep the process on demand; do not add it to the persistent Quickshell apps.
- Decode only visible image thumbnails and the currently hovered preview.
- Keep preview decoding delayed so pointer movement across the list does not
  launch a process for every transient row.
- Refresh is driven solely by `cliphistService update` IPC from
  `bin/sumika-clipboard-store` (the `wl-paste --watch` layer). Do not add a
  `Quickshell.onClipboardTextChanged` listener — it fires for our own
  `/tmp/sumika-clip-*` path writes and causes redundant refreshes.
- History is capped at 40 entries (`Cliphist.maxEntries`).
