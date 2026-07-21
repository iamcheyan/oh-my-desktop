# Smart Paste — Image as Path in Terminals

Terminals (kitty, alacritty, foot, …) cannot render image clipboard data, so
pasting an image into them does nothing. "Smart paste" detects when the
clipboard holds an image **and** the target is a terminal, and instead pastes
the image's **file path** (saved under `/tmp`) — most CLI tools accept a path
argument. In every other case (text clipboard, or a non-terminal target) the
normal paste behavior is preserved.

There are two entry points to the same idea, implemented independently:

1. **Clipboard manager** — clicking an image entry pastes it as a path when
   the focused window is a terminal (no need to click the dedicated "paste as
   path" `⇲` button).
2. **kitty `Ctrl+V`** — pressing `Ctrl+V` in kitty pastes an image as a path
   (or pastes text normally).

---

## 1. Clipboard manager: click image → paste as path

### Goal

In the OMD clipboard manager (`omd-clipboard`), image entries already had a
dedicated "paste as path" button on the right (`⇲`, calling
`Cliphist.pasteImagePath`). The optimization: clicking the image entry itself
(the main click action) should paste as a path **when the focused window is a
terminal**, so the user doesn't need to aim for the small button. Non-terminal
targets keep normal paste (GUI apps render the image).

### How it works

`Cliphist.pasteSmart(entry)` decides at paste time:

- If the entry is **not** an image → delegate to the existing `Cliphist.paste`
  (decode entry → `wl-copy` → `omd-paste-at-cursor auto`).
- If the entry **is** an image → run a single bash command that:
  1. Reads the focused window class: `hyprctl activewindow -j | jq -r '.class'`.
  2. Matches it against the terminal list (`kitty`, `alacritty`, `foot`,
     `wezterm`, `xterm`, `XTerm`, `tmux`, `urxvt`, `Rxvt`, `st-terminal`).
  3. If it's a terminal → image-to-path: `cliphist decode > /tmp/omd-clip-<ts>.png`,
     `wl-copy` the path, `omd-paste-at-cursor auto`, `notify-send`.
  4. Otherwise → normal image paste: `cliphist decode | wl-copy`,
     `omd-paste-at-cursor auto`.

The terminal detection runs **inside the bash command** (not in QML) because
the OMD clipboard app is a separate Quickshell process without access to the
`HyprlandData` singleton; `hyprctl activewindow` is the lightweight way to get
the focused window class.

### Key insight: focus timing

The clipboard dialog is a `WlrLayershell` overlay (`WlrLayer.Overlay`,
`WlrKeyboardFocus.Exclusive` when open). Layer-shell surfaces are **not** xdg
toplevels, so `hyprctl activewindow` still reports the real target terminal
even while the dialog is open. Verified empirically: with the dialog open,
`hyprctl activewindow -j` returns `kitty`, not the dialog. So the terminal
detection at click time is correct.

The existing `paste`/`pasteImagePath` functions already rely on a short delay
before `omd-paste-at-cursor auto` so the dialog can dismiss and keyboard focus
returns to the target window; `pasteSmart` reuses the same `pressPasteCommand`
and timing.

### Files changed (commit `11c4fa4`)

| File | Change |
|---|---|
| `apps/omd-clipboard/services/Cliphist.qml` | Added `pasteSmart(entry)` function (terminal-detection bash + image→path / normal-paste branching). Clipboard menu paste uses `omd-paste-at-cursor auto`, not hard-coded `ydotool Ctrl+V`. |
| `apps/omd-clipboard/modules/clipboard/widgets/ClipboardItem.qml` | Main `onClicked` now calls `Cliphist.pasteSmart(root.entry)` instead of `Cliphist.paste(root.entry)`. |
| `apps/omd-clipboard/modules/clipboard/ClipboardDialog.qml` | `pasteSelected(asPath)` else-branch (keyboard Enter) calls `Cliphist.pasteSmart(entry)` for consistency. |

The dedicated `⇲` button (`pasteAsPathRequested` → `Cliphist.pasteImagePath`) is
unchanged and still forces paste-as-path regardless of target.

### Verification

- Mock-tested the bash logic for both branches (terminal → creates
  `/tmp/omd-clip-*.png` + `wl-copy` path + `omd-paste-at-cursor` + notify;
  non-terminal → `wl-copy` raw image bytes + `omd-paste-at-cursor`).
- Loaded the `omd-clipboard` app to confirm no QML syntax errors.
- Confirmed `hyprctl activewindow` returns the terminal while the dialog is open.

---

## 2. kitty `Ctrl+V`: paste image as path

### Goal

Pressing `Ctrl+V` in kitty should paste the clipboard image as a `/tmp` path
(when the clipboard holds an image), and paste text normally otherwise —
replacing kitty's native `paste_from_clipboard` for this key.

### Approach: background launcher + targeted native paste

kitty.conf maps `Ctrl+V` to launch a background script:

```conf
map ctrl+v launch --type=background ~/.config/omd/bin/omd-kitty-smart-paste
```

The script (`bin/omd-kitty-smart-paste`):

1. Resolves the kitty remote-control socket (see "Socket resolution" below).
2. Checks `wl-paste -l` for an image MIME type.
3. If image → save to `/tmp/omd-clip-<ts>.<ext>` and publish its path as text.
4. If no image → snapshot the clipboard text.
5. Delegate both cases to `omd-paste-at-cursor`, which resolves one Kitty window
   ID and runs `kitty @ action --match id:<id> paste_from_clipboard`.

The remote action invokes Kitty's native paste implementation without
re-injecting `Ctrl+V`, so it cannot recursively trigger this binding. It also
preserves bracketed-paste semantics: CLI/TUI applications receive one complete
paste transaction instead of processing the payload as typed characters. The
compatibility fallback is `send-text --bracketed-paste auto` with the clipboard
temporarily cleared to prevent OMP OSC 5522 duplicate insertion.

### Socket resolution

`launch --type=background` does **not** set the `KITTY_LISTEN_ON` environment
variable for the child process. The script now resolves the socket in this
order:

1. `KITTY_LISTEN_ON`, when present.
2. The focused Hyprland kitty window PID: `/tmp/mykitty-<pid>`.
3. A kitty parent in the process tree: `/tmp/mykitty-<pid>`.
4. A single existing `/tmp/mykitty-*` socket.
5. `/tmp/mykitty`, then the first available `/tmp/mykitty-*` as a last resort.

This matters on machines with multiple kitty windows, because `listen_on
unix:/tmp/mykitty` creates per-process sockets such as `/tmp/mykitty-78386`.

```sh
resolve_socket() {
  if [ -n "${KITTY_LISTEN_ON:-}" ]; then echo "$KITTY_LISTEN_ON"; return; fi
  active_pid=$(hyprctl activewindow -j 2>/dev/null | jq -r 'select(.class? | test("kitty"; "i")) | .pid // empty' 2>/dev/null || true)
  if [ -n "$active_pid" ] && [ -S "/tmp/mykitty-$active_pid" ]; then
    echo "unix:/tmp/mykitty-$active_pid"; return
  fi
  p=$$
  for _ in 1 2 3 4 5 6; do
    p=$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')
    [ -z "$p" ] || [ "$p" = 0 ] && break
    name=$(ps -o comm= -p "$p" 2>/dev/null | tr -d ' ')
    if [ "$name" = "kitty" ] && [ -S "/tmp/mykitty-$p" ]; then
      echo "unix:/tmp/mykitty-$p"; return
    fi
  done
  set -- /tmp/mykitty-*
  if [ $# -eq 1 ] && [ -S "$1" ]; then echo "unix:$1"; return; fi
  if [ -S /tmp/mykitty ]; then echo "unix:/tmp/mykitty"; return; fi
  for sock in /tmp/mykitty-*; do
    if [ -S "$sock" ]; then echo "unix:$sock"; return; fi
  done
  echo "unix:/tmp/mykitty"
}
```

### Interaction with the clipboard manager

The clipboard manager's `paste`/`pasteSmart` paste by putting content on the
clipboard and calling `omd-paste-at-cursor auto`. In kitty, that helper prefers
kitty remote control and pastes the current clipboard payload directly; this
avoids depending on `ydotoold` and avoids keyboard-layout scancode issues.

### Files changed

| File | Change | Commit |
|---|---|---|
| `bin/omd-kitty-smart-paste` (OMD) | New script: socket resolution + image→path / text paste via `kitty @ send-text`. | `16da277` |
| `~/dotfiles/config/kitty/kitty.conf` (dotfiles repo) | `map ctrl+v paste_from_clipboard` → `map ctrl+v launch --type=background ~/.config/omd/bin/omd-kitty-smart-paste`. | `8ee5a13` |

The script lives in OMD (reusable, like other `omd-*` binaries) and is
referenced via `~/.config/omd/bin/...` (resolves through the
`~/.config/omd -> ~/development/OMD` symlink). kitty expands `~` in `launch`
paths (verified).

### Verification (end-to-end, in a throwaway window)

To avoid pasting into the user's working window, the test creates a temporary
kitty window running `cat` (which echoes received text), triggers `Ctrl+V` via
`ydotool`, and reads the window text back with `kitty @ get-text`:

1. `kitty @ launch --type=window --title OMDTEST cat` + `focus-window`.
2. Put an image on the clipboard (`wl-copy --type image/png`).
3. `ydotool key 29:1 47:1 47:0 29:0` (Ctrl+V) → fires the bind → script.
4. `kitty @ get-text --match title:OMDTEST` → confirmed the path
   `/tmp/omd-clip-<ts>.png` appeared in the `cat` window.
5. Text branch: put text on the clipboard, repeat → confirmed the text appeared.
6. Close the throwaway window, restore the original clipboard.

Both branches passed. The script logs each invocation to
`/tmp/omd-kitty-smart-paste.log` (one line: socket + decision) for debugging.

---

## 3. Config location: TWM migration (prerequisite)

The kitty `Ctrl+V` work initially "did nothing" because the **wrong config
file** was being edited. This is documented here so it doesn't recur.

### The problem

`~/.config/kitty` and `config/kitty/kitty.conf` have moved through several
layouts during migration. On one machine, `config/kitty/kitty.conf` was still a
symlink to `~/dotfiles/config/kitty/kitty.conf`; that external file contained
`map ctrl+v paste_from_clipboard`, so the smart-paste script existed but was
never called.

OMD now keeps `config/kitty/kitty.conf` as a real tracked file with:

```conf
map ctrl+v launch --type=background ~/.config/omd/bin/omd-kitty-smart-paste
```

If this feature works on one machine but not another, check the actual loaded
file and mapping:

```sh
readlink -f ~/.config/kitty/kitty.conf
grep -n 'ctrl+v\\|omd-kitty-smart-paste\\|paste_from_clipboard' ~/.config/kitty/kitty.conf
```

### What was done

- **Backed up TWM**: committed the local TWM state and pushed to GitHub branch
  `archive/local-snapshot-20260718` (commit `f66123d`). Remote `main` was
  divergent (force-pushed) and left untouched.
- **Migrated the actively-used configs** to dotfiles management:
  - `kitty` → `~/dotfiles/config/kitty/` (`kitty.conf` + `scroll_mark.py` +
    `search.py`), `~/.config/kitty` repointed here.
  - `cliphist` → `~/dotfiles/config/cliphist/` (`config` read by the `cliphist`
    binary for `max-items 100` etc., plus the fuzzel/wofi wrapper scripts),
    `~/.config/cliphist` repointed here.
- **Removed 23 dormant symlinks** into TWM (`hypr`, `sway`, `waybar`, `niri`,
  `labwc`, `i3`, `polybar`, `mako`, `swaync`, `fuzzel`, `wofi`, `sfwbar`,
  `xterm`, `TWM`, `qt5ct`/`qt6ct`, `save-displays`, labwc themes, backup-dir
  links). These were all dormant in the current OMD/Hyprland+Quickshell
  session (verified: Hyprland uses `-c ~/.config/omd/hypr/hyprland.lua`,
  `hypridle` uses `-c ~/.config/omd/hypr/hypridle.conf`, `hyprsunset` has no
  config file, `swaybg` doesn't read `~/.config/sway`, `QT_QPA_PLATFORMTHEME=kde`
  ignores qt5ct/qt6ct, and the other WMs/bars are not running).
- **Deleted `~/dotfiles/TWM`**.

After this, `~/.config/kitty/kitty.conf` resolves to the dotfiles-managed file,
and edits there take effect.

---

## 4. Pitfalls & lessons learned

These are recorded so the same mistakes aren't repeated.

1. **Hyprland `send_key_state` recursion → freeze (abandoned).** The first
   attempt was a Hyprland `bind CTRL + V` that, for the non-image/non-terminal
   case, forwarded a real `Ctrl+V` via `hl.dsp.send_key_state`. The synthesized
   `Ctrl+V` retriggered the same bind → infinite recursion → the Hyprland event
   loop pegged → the whole desktop froze. `send_key_state` does **not** bypass
   bind matching (contrary to a comment that was written). This approach was
   abandoned and reverted. **The kitty `launch` + `send-text` approach has no
   such recursion because `send-text` injects text, not a keypress.**

2. **Editing the wrong kitty config file.** `~/.config/kitty` pointed to
   `~/dotfiles/TWM/kitty`, not the OMD/dotfiles file. Always check
   `readlink -f ~/.config/kitty/kitty.conf` to find the file kitty actually
   loads before editing.

3. **`SIGHUP` closes kitty, it does not reload it.** Terminal programs treat
   `SIGHUP` as hangup = exit. Sending `SIGHUP` to kitty **killed it** (and lost
   the user's terminal sessions). To reload kitty's config without restarting:
   press `Ctrl+Shift+F5` (the `reload_config` action, can be sent via
   `ydotool`), or simply restart kitty. (kitty does **not** reload on SIGHUP.)

4. **`watch_conf` watches the inode at startup.** kitty's config-file watcher
   is established when kitty starts, on the inode of the config file at that
   moment. Repointing the `~/.config/kitty` symlink to a new file does **not**
   update the watch — the watcher keeps watching the old (possibly deleted)
   inode, so edits to the new file won't auto-reload. A kitty restart
   re-establishes the watch on the new path. (After the TWM migration, kitty
   was restarted, so the watch now correctly points at the dotfiles-managed
   file.)

5. **`launch --type=background` doesn't set `KITTY_LISTEN_ON`.** The background
   child must find the kitty socket itself (process-tree walk to the kitty
   parent → `/tmp/mykitty-<pid>`). The socket path is PID-suffixed
   (`/tmp/mykitty-<pid>`), not the bare `/tmp/mykitty` from `listen_on`.

6. **Layer-shell overlays don't appear in `hyprctl activewindow`.** The
   clipboard dialog is a `WlrLayer.Overlay`; `hyprctl activewindow` reports the
   last focused xdg toplevel (the terminal) even while the dialog has keyboard
   focus. This is why terminal detection from the clipboard manager works at
   click time.

---

## 5. How to use / test

### Clipboard manager

Open the clipboard manager (`Ctrl+Shift+V`), focus a terminal, and click an
image entry → it pastes the `/tmp/omd-clip-*.png` path. Focus a non-terminal
(e.g. a browser) and click an image → it pastes the image normally. The `⇲`
button still forces paste-as-path regardless of target.

### kitty `Ctrl+V`

In kitty, copy an image to the clipboard (e.g. a screenshot), then press
`Ctrl+V` → the path `/tmp/omd-clip-<ts>.png` is typed into the terminal and a
notification appears. With text on the clipboard, `Ctrl+V` pastes the text as
before.

### Reload after editing `kitty.conf`

Because `watch_conf` now watches the correct file, kitty auto-reloads on
`kitty.conf` edits. To force a reload without waiting: `Ctrl+Shift+F5` in
kitty, or restart kitty. **Do not use `SIGHUP`** (it closes kitty).

### Debug log

`/tmp/omd-kitty-smart-paste.log` records each `Ctrl+V` invocation (socket +
decision: `image->path <tmp>` or `text paste`). Remove or gate this log if it
becomes noisy.
