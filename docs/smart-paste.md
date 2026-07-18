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
  (decode entry → `wl-copy` → `ydotool Ctrl+V`).
- If the entry **is** an image → run a single bash command that:
  1. Reads the focused window class: `hyprctl activewindow -j | jq -r '.class'`.
  2. Matches it against the terminal list (`kitty`, `alacritty`, `foot`,
     `wezterm`, `xterm`, `XTerm`, `tmux`, `urxvt`, `Rxvt`, `st-terminal`).
  3. If it's a terminal → image-to-path: `cliphist decode > /tmp/omd-clip-<ts>.png`,
     `wl-copy` the path, `ydotool Ctrl+V`, `notify-send`.
  4. Otherwise → normal image paste: `cliphist decode | wl-copy`, `ydotool Ctrl+V`.

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

The existing `paste`/`pasteImagePath` functions already rely on a `sleep 0.1`
before `ydotool Ctrl+V` so the dialog can dismiss and keyboard focus returns to
the target window; `pasteSmart` reuses the same `pressPasteCommand` and timing.

### Files changed (commit `11c4fa4`)

| File | Change |
|---|---|
| `apps/omd-clipboard/services/Cliphist.qml` | Added `pasteSmart(entry)` function (terminal-detection bash + image→path / normal-paste branching). |
| `apps/omd-clipboard/modules/clipboard/widgets/ClipboardItem.qml` | Main `onClicked` now calls `Cliphist.pasteSmart(root.entry)` instead of `Cliphist.paste(root.entry)`. |
| `apps/omd-clipboard/modules/clipboard/ClipboardDialog.qml` | `pasteSelected(asPath)` else-branch (keyboard Enter) calls `Cliphist.pasteSmart(entry)` for consistency. |

The dedicated `⇲` button (`pasteAsPathRequested` → `Cliphist.pasteImagePath`) is
unchanged and still forces paste-as-path regardless of target.

### Verification

- Mock-tested the bash logic for both branches (terminal → creates
  `/tmp/omd-clip-*.png` + `wl-copy` path + `ydotool` + notify; non-terminal →
  `wl-copy` raw image bytes + `ydotool`).
- Loaded the `omd-clipboard` app to confirm no QML syntax errors.
- Confirmed `hyprctl activewindow` returns the terminal while the dialog is open.

---

## 2. kitty `Ctrl+V`: paste image as path

### Goal

Pressing `Ctrl+V` in kitty should paste the clipboard image as a `/tmp` path
(when the clipboard holds an image), and paste text normally otherwise —
replacing kitty's native `paste_from_clipboard` for this key.

### Approach: `launch --type=background` + `kitty @ send-text`

kitty.conf maps `Ctrl+V` to launch a background script:

```conf
map ctrl+v launch --type=background ~/.config/omd/bin/omd-kitty-smart-paste
```

The script (`bin/omd-kitty-smart-paste`):

1. Resolves the kitty remote-control socket (see "Socket resolution" below).
2. Checks `wl-paste -l` for an image MIME type.
3. If image → save to `/tmp/omd-clip-<ts>.<ext>` → `printf '%s ' "$tmp" | kitty @ --to "$KC" send-text --stdin --bracketed-paste auto` → `notify-send`.
4. If no image → `wl-paste | kitty @ --to "$KC" send-text --stdin --bracketed-paste auto` (equivalent to native `paste_from_clipboard`).

`kitty @ send-text` injects text **directly into the active kitty window** (not
as a keypress), so it does **not** retrigger the `Ctrl+V` bind — there is no
recursion and no freeze risk. `--bracketed-paste auto` wraps the text in
bracketed-paste escape codes only when the running program enabled bracketed
paste mode, matching kitty's native paste behavior.

### Socket resolution

`launch --type=background` does **not** set the `KITTY_LISTEN_ON` environment
variable for the child process. The script finds the socket by walking up the
process tree to the `kitty` parent and using `/tmp/mykitty-<pid>` (kitty
appends the PID to the `listen_on` path to avoid multi-instance collisions).
Fallbacks: a single existing `/tmp/mykitty-*` socket, then `unix:/tmp/mykitty`.

```sh
resolve_socket() {
  if [ -n "${KITTY_LISTEN_ON:-}" ]; then echo "$KITTY_LISTEN_ON"; return; fi
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
  echo "unix:/tmp/mykitty"
}
```

### Interaction with the clipboard manager

The clipboard manager's `paste`/`pasteSmart` paste by putting content on the
clipboard and sending `ydotool Ctrl+V`. With this kitty bind, that `Ctrl+V` is
intercepted by kitty and runs the smart-paste script. The script re-reads the
clipboard (which now holds the path text) → no image → pastes the text. So both
flows route through the script consistently and work end-to-end.

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

`~/.config/kitty` was a symlink to `~/dotfiles/TWM/kitty` (a separate git
repo, `iamcheyan/TWM`). OMD's own `config/kitty/kitty.conf` symlinked to a
**different** file (`~/dotfiles/config/kitty/kitty.conf`, different font/content)
that kitty did **not** load. Early edits went to the unused file, so binds never
took effect.

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