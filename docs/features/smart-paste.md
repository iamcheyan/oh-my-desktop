# Smart Paste

Smart paste converts image clipboard data to a temporary file path when the
target is a terminal. Text and GUI image paste retain native clipboard
behavior.

## User Behavior

- Selecting text in the clipboard menu pastes the decoded text.
- Selecting an image while a terminal is the target creates
  `/tmp/omd-clip-<timestamp>.<ext>` and pastes that path.
- Selecting an image for a GUI application pastes its image MIME data.
- The explicit path action always converts the image to a path.
- Kitty `Ctrl+V` remains native; its configured smart-paste chord delegates to
  the same central pipeline.

## Single Paste Pipeline

Every programmatic paste must call:

```sh
~/.config/omd/bin/omd-paste-at-cursor
```

Feature code must not directly add `kitty @ send-text`, `wtype`, `ydotool`, or
Hyprland key injection. The helper owns payload capture, target resolution,
terminal dispatch, bracketed paste, fallbacks, duplicate suppression, and
diagnostic logging.

Prefer an immutable file payload:

```sh
payload=$(mktemp)
trap 'rm -f "$payload"' EXIT
printf '%s' "$text" > "$payload"
OMD_PASTE_SOURCE=my-feature \
  ~/.config/omd/bin/omd-paste-at-cursor --file "$payload" auto
```

The clipboard service decodes cliphist entries before invoking the helper. It
uses `hyprctl activewindow -j` to resolve the xdg-toplevel target because the
clipboard menu itself is a layer-shell surface and is not the target window.

## Terminal Rules

- Kitty receives one targeted native paste through remote control and a
  resolved window ID.
- Never use Kitty `--match state:focused`; it may match multiple windows.
- Never send a large payload as unbracketed typed characters. Raw-input TUI
  programs process it byte by byte and appear to paste one character at a time.
- Non-Kitty terminals receive one native paste chord, with `wtype` preferred
  over `ydotool` and Hyprland synthetic key state.

The detailed Kitty/OMP constraints and diagnostics are maintained in
[Paste Pipeline and Kitty/TUI Conflicts](paste-kitty-conflicts.md).

## Key Files

- `apps/omd-clipboard/services/Cliphist.qml`
- `apps/omd-clipboard/modules/clipboard/ClipboardDialog.qml`
- `apps/omd-clipboard/modules/clipboard/widgets/ClipboardItem.qml`
- `bin/omd-paste-at-cursor`
- `bin/omd-kitty-smart-paste`

## Verification

Test text and image entries against a GUI application, a plain shell, Kitty,
and a raw-input CLI/TUI. Each user action must insert exactly once, and large
text must arrive as one bracketed paste transaction rather than typed bytes.
