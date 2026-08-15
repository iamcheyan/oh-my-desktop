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

### SSH-aware remote path

Both image→path entry points (`sumika-clipboard-paste --path/--smart` and
`sumika-kitty-smart-paste`) ask `bin/sumika-clipboard-image-path` where the
path should live before writing the clipboard. When the focused terminal runs
an ssh session, the image is streamed to the remote `/tmp` and the REMOTE path
is pasted — a local path would not exist on the machine that reads it:

1. Resolve the focused terminal (Hyprland `activewindow` pid; kitty remote
   `ls` window pid as the labwc fallback) and walk its `/proc` tree for an
   `ssh` process. The root must cover exactly the tab the user types in:
   kitty hosts every tab in one process, so the walk root is scoped to the
   focused tab's shell pid (focused OS window → active tab → focused window)
   — walking kitty's whole tree would pick up ssh sessions from OTHER tabs
   and misdirect local pastes to a remote host. Terminals that share one
   process across tabs but expose no per-tab query (wezterm, ghostty,
   konsole) are skipped entirely: no detection, historical local path. tmux
   clients found in the tree are followed into their server session (matched
   by `client_pid`, so other attached sessions are never probed) because
   pane processes are parented by the tmux server, not by the terminal
   window.

BatchMode guarantees no password prompt can hang the paste: password-only
hosts, unreachable machines and key-verification failures all fall back to
the historical local path, and the notification says so. Limitations: only
the first ssh hop is visible (nested ssh or a tmux running on the remote
host cannot be resolved locally), and zellij panes are not followed.

`SUMIKA_CLIPBOARD_SSH_IMAGE=0` disables the remote attempt entirely.
Diagnostics: `sumika-clipboard-image-path --probe` (prints the detected
session) and `${XDG_RUNTIME_DIR:-/tmp}/sumika-clipboard/ssh-image.log`.

### Exactly-once (duplicate paste suppression)

A fast re-trigger (kitty key repeat, double Ctrl+Shift+V) used to paste the
path twice: each run mints a NEW timestamped path, so the payload-hash dedupe
in `sumika-paste-at-cursor` never matched; after the first paste the Wayland
clipboard holds the path TEXT — or kitty's own clipboard buffer re-offers the
previous image — so the second trigger pasted again. Three layers now make
one user action one paste:

1. `sumika-clipboard-image-path` keys a dedupe state on the image CONTENT
   (sha256, window `SUMIKA_CLIPBOARD_IMAGE_DEDUPE_MS`, default 1200 ms) and
   exits 3 on a repeat; both callers treat 3 as "already pasted, do nothing".
2. The helper records the minted path in
   `$XDG_RUNTIME_DIR/sumika-clipboard/last-path`; the kitty text branch
   refuses to paste that exact path again within
   `SUMIKA_CLIPBOARD_PATH_GUARD_MS` (default 2000 ms).
3. Both image-path flows inject with `SUMIKA_PASTE_DEDUPE_MS=1200` (default
   500) so identical path payloads collapse into one injection.

Deliberate repeats outside those windows behave as before.

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
