#!/usr/bin/env python3
"""Shared helpers for Python curses settings TUIs.

Port of tui-go/internal/ui/*.go — provides the same visual primitives
(PrimaryLine, ActionLine, ToggleLine, CycleLine, SegmentedLine, KVLine,
Hero, SectionTitle, StatusDot, ProgressBar, etc.) so each Python TUI can
render identically to the Go version.
"""

import curses
import locale
import os
import queue
import subprocess
import threading
import time
import unicodedata
from pathlib import Path

SUMIKA_SHELL_ROOT = (
    os.environ.get("SUMIKA_SHELL_ROOT")
    or str(Path(__file__).resolve().parent.parent)
)

# ── colour pairs ─────────────────────────────────────────────────────────
C_BG, C_FG, C_ACCENT, C_MUTED = 0, 1, 2, 3
C_OK, C_WARN, C_DANGER, C_SECTION = 4, 5, 6, 7
C_BORDER, C_SUBTLE, C_PANEL = 8, 9, 10
# Extended pairs for theme swatches (11..30 allocated at runtime)
C_THEME_START = 11
C_FOCUS_BORDER = 31
C_OVERLAY = 32  # black-on-black scrim (modal overlays)

# Theme accent color cache (loaded from quickshell.json)
_THEME_ACCENT = None  # (r, g, b) or None

# xterm-256 extended color palette levels (for colors 16-231)
_XTERM_LEVELS = (0, 95, 135, 175, 215, 255)


def _xterm_rgb(index):
    """Return the standard RGB value for an xterm-256 extended color index."""
    if 16 <= index <= 231:
        value = index - 16
        return (
            _XTERM_LEVELS[value // 36],
            _XTERM_LEVELS[(value // 6) % 6],
            _XTERM_LEVELS[value % 6],
        )
    if 232 <= index <= 255:
        level = 8 + (index - 232) * 10
        return (level, level, level)
    return (0, 0, 0)


def _nearest_xterm_index(r, g, b):
    """Find the nearest xterm-256 color index (16-255) for an RGB value.

    Uses perceptual (redmean) weighting so saturated colors are not mistakenly
    mapped to the grey ramp.  Never calls init_color(), so the terminal's
    global color table is never modified.
    """
    def dist(idx):
        cr, cg, cb = _xterm_rgb(idx)
        dr, dg, db = r - cr, g - cg, b - cb
        r_mean = (r + cr) >> 1
        wr = 2 + (r_mean >> 7)
        return wr * dr * dr + 4 * dg * dg + 3 * db * db

    return min(range(16, 256), key=dist)


def _load_theme_accent():
    """Try to load the primary accent color from the active theme.
    Returns (r,g,b) on success, None on failure (file missing, parse error, etc.).
    """
    try:
        import json
        sumika_state = os.environ.get(
            "SUMIKA_SHELL_STATE_HOME",
            os.path.join(os.environ.get("XDG_STATE_HOME", os.path.expanduser("~/.local/state")), "sumika-shell")
        )
        path = os.path.join(sumika_state, "theme", "current", "quickshell.json")
        with open(path) as f:
            data = json.load(f)
        primary = data.get("primary", "")
        if primary and primary.startswith("#") and len(primary) == 7:
            r = int(primary[1:3], 16)
            g = int(primary[3:5], 16)
            b = int(primary[5:7], 16)
            return (r, g, b)
    except (FileNotFoundError, json.JSONDecodeError, ValueError, KeyError, OSError):
        pass
    return None


def _load_theme_border_color():
    """Load the active_border_color from colors.toml.
    Returns (r,g,b) on success, None on failure.
    """
    try:
        sumika_state = os.environ.get(
            "SUMIKA_SHELL_STATE_HOME",
            os.path.join(os.environ.get("XDG_STATE_HOME", os.path.expanduser("~/.local/state")), "sumika-shell")
        )
        path = os.path.join(sumika_state, "theme", "current", "colors.toml")
        with open(path) as f:
            for line in f:
                line = line.strip()
                if line.startswith("active_border_color"):
                    hex_val = line.split("=", 1)[1].strip().strip('"')
                    if hex_val.startswith("#") and len(hex_val) == 7:
                        r = int(hex_val[1:3], 16)
                        g = int(hex_val[3:5], 16)
                        b = int(hex_val[5:7], 16)
                        return (r, g, b)
    except (FileNotFoundError, OSError, ValueError, IndexError):
        pass
    return None


_callback_queue = queue.SimpleQueue()

def init_colors():
    global ATTR_SECTION, ATTR_FOCUS, ATTR_OK, ATTR_WARN, ATTR_DANGER
    global ATTR_ACTION, ATTR_MUTED, ATTR_SUBTLE, ATTR_TEXT, ATTR_BORDER, TAG_STYLE
    global ATTR_PRIMARY, ATTR_DANGER_ACTION, ATTR_OK_BOLD, ATTR_ACCENT_BOLD, ATTR_FOCUS_BORDER
    global C_FOCUS_BORDER, ATTR_OVERLAY
    if not curses.has_colors():
        return
    curses.start_color()
    try:
        curses.use_default_colors()
    except curses.error:
        pass
    bg = -1
    curses.init_pair(C_FG,      curses.COLOR_WHITE,  bg)
    # Accent: try theme primary mapped to nearest xterm-256 fixed color.
    # We never call init_color() — that would mutate the terminal's global
    # color table and corrupt colors in every other TUI in the session.
    theme_rgb = _load_theme_accent()
    colors = getattr(curses, "COLORS", 8)
    accent_set = False
    if theme_rgb and colors >= 256:
        r, g, b = theme_rgb
        try:
            xterm_idx = _nearest_xterm_index(r, g, b)
            curses.init_pair(C_ACCENT, xterm_idx, bg)
            accent_set = True
        except curses.error:
            pass
    if not accent_set:
        curses.init_pair(C_ACCENT, curses.COLOR_CYAN, bg)
    curses.init_pair(C_MUTED,   curses.COLOR_WHITE,  bg)
    curses.init_pair(C_OK,      curses.COLOR_GREEN,  bg)
    curses.init_pair(C_WARN,    curses.COLOR_YELLOW, bg)
    curses.init_pair(C_DANGER,  curses.COLOR_RED,    bg)
    curses.init_pair(C_SECTION, curses.COLOR_CYAN,   bg)
    colors = getattr(curses, "COLORS", 8)
    border = 240 if colors > 240 else curses.COLOR_WHITE
    subtle = 245 if colors > 245 else curses.COLOR_WHITE
    panel = 236 if colors > 236 else curses.COLOR_BLACK
    curses.init_pair(C_BORDER,  border,              bg)
    curses.init_pair(C_SUBTLE,  subtle,              bg)
    curses.init_pair(C_PANEL,   panel,               bg)
    ATTR_SECTION = attr(C_SECTION, True)
    ATTR_FOCUS   = attr(C_ACCENT, True)
    ATTR_OK      = attr(C_OK)
    ATTR_WARN    = attr(C_WARN, True)
    ATTR_DANGER  = attr(C_DANGER)
    ATTR_ACTION  = attr(C_FG)
    ATTR_MUTED   = attr(C_MUTED, False) | curses.A_DIM
    ATTR_SUBTLE  = attr(C_SUBTLE)
    ATTR_TEXT    = attr(C_FG)
    ATTR_BORDER  = attr(C_BORDER) | curses.A_DIM
    ATTR_PRIMARY = attr(C_ACCENT, True)
    ATTR_DANGER_ACTION = attr(C_DANGER)
    ATTR_OK_BOLD = attr(C_OK, True)
    ATTR_ACCENT_BOLD = attr(C_ACCENT, True)
    # Focus border: try theme active_border_color, fall back to accent
    border_rgb = _load_theme_border_color()
    border_set = False
    if border_rgb and colors >= 256:
        r, g, b = border_rgb
        try:
            xterm_idx = _nearest_xterm_index(r, g, b)
            curses.init_pair(C_FOCUS_BORDER, xterm_idx, bg)
            border_set = True
        except curses.error:
            pass
    if not border_set:
        # Share C_ACCENT's pair index so the pair is already initialized
        C_FOCUS_BORDER = C_ACCENT  # type: ignore
    ATTR_FOCUS_BORDER = attr(C_FOCUS_BORDER, True)
    curses.init_pair(C_OVERLAY, curses.COLOR_BLACK, curses.COLOR_BLACK)
    ATTR_OVERLAY = attr(C_OVERLAY)
    TAG_STYLE = {
        "section": ATTR_SECTION,
        "focus":   ATTR_FOCUS,
        "ok":      ATTR_OK,
        "warn":    ATTR_WARN,
        "danger":  ATTR_DANGER,
        "action":  ATTR_ACTION,
        "muted":   ATTR_MUTED,
        "subtle":  ATTR_SUBTLE,
        "text":    ATTR_TEXT,
        "primary": ATTR_PRIMARY,
        "danger_action": ATTR_DANGER_ACTION,
    }

def attr(pair, bold=False):
    a = curses.color_pair(pair)
    if bold:
        a |= curses.A_BOLD
    return a

# ── attrs (set by init_colors) ────────────────────────────────────────────
ATTR_SECTION = 0
ATTR_FOCUS   = 0
ATTR_OK      = 0
ATTR_WARN    = 0
ATTR_DANGER  = 0
ATTR_ACTION  = 0
ATTR_MUTED   = 0
ATTR_SUBTLE  = 0
ATTR_TEXT    = 0
ATTR_BORDER  = 0
ATTR_PRIMARY = 0
ATTR_DANGER_ACTION = 0
ATTR_OK_BOLD = 0
ATTR_ACCENT_BOLD = 0
ATTR_FOCUS_BORDER = 0
ATTR_OVERLAY = 0
TAG_STYLE    = {}

# ── backend ──────────────────────────────────────────────────────────────
def run_cmd(name, *args, timeout=15):
    # If name is absolute, use it directly; otherwise look in the Sumika bin directory.
    # Default timeout suits status probes; long actions (installs, compose up)
    # must pass a larger timeout or they get SIGKILLed mid-run.
    if os.path.isabs(name):
        path = name
    else:
        path = os.path.join(SUMIKA_SHELL_ROOT, "bin", name)
    try:
        r = subprocess.run(
            [path, *args], stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            text=True, errors="replace", timeout=timeout, cwd=SUMIKA_SHELL_ROOT,
        )
        lines = [line for line in r.stdout.splitlines() if line]
        error = "" if r.returncode == 0 else f"exit {r.returncode}"
        return lines, error
    except Exception as e:
        return [str(e)], str(e)

def run_cmd_bg(name, *args, callback=None, timeout=15):
    def _w():
        lines, err = run_cmd(name, *args, timeout=timeout)
        if callback:
            _callback_queue.put((callback, lines, err))
    threading.Thread(target=_w, daemon=True).start()


def drain_callbacks(limit=128):
    """Run completed worker callbacks on the curses/UI thread."""
    count = 0
    while count < limit:
        try:
            callback, lines, err = _callback_queue.get_nowait()
        except queue.Empty:
            break
        callback(lines, err)
        count += 1
    return count

def parse_kv(lines):
    d = {}
    raw = "\n".join(lines)
    d["__raw__"] = raw
    for l in lines:
        if "=" in l:
            k, v = l.split("=", 1)
            d[k.strip()] = v.strip()
    return d

# ── drawing ──────────────────────────────────────────────────────────────
def char_width(ch):
    if not ch or unicodedata.combining(ch):
        return 0
    category = unicodedata.category(ch)
    if category.startswith("C"):
        return 0
    return 2 if unicodedata.east_asian_width(ch) in ("W", "F") else 1


def text_width(text):
    return sum(char_width(ch) for ch in str(text))


def _slice_width(text, width):
    if width <= 0:
        return ""
    out = []
    used = 0
    for ch in str(text):
        cw = char_width(ch)
        if used + cw > width:
            break
        out.append(ch)
        used += cw
    return "".join(out)


def safe_addstr(win, y, x, text, a=0):
    h, w = win.getmaxyx()
    if y < 0 or y >= h or x < 0 or x >= w - 1:
        return
    try:
        win.addstr(y, x, _slice_width(text, w - 1 - x), a)
    except curses.error:
        pass

def truncate(text, width):
    text = str(text)
    if width <= 0:
        return ""
    if text_width(text) <= width:
        return text
    if width == 1:
        return "…"
    return _slice_width(text, width - 1) + "…"


def pad_to_width(text, width):
    clipped = truncate(text, width)
    return clipped + " " * max(0, width - text_width(clipped))


def wrap_text(text, width):
    """Wrap text to terminal columns without splitting wide characters."""
    if width <= 0:
        return []
    text = str(text)
    if not text:
        return [""]
    rows = []
    current = []
    used = 0
    for ch in text:
        if ch == "\n":
            rows.append("".join(current))
            current, used = [], 0
            continue
        cw = char_width(ch)
        if current and used + cw > width:
            rows.append("".join(current))
            current, used = [], 0
        current.append(ch)
        used += cw
    rows.append("".join(current))
    return rows


def wrapped_lines(lines, width):
    """Expand logical lines into the terminal rows they occupy."""
    rows = []
    for line in lines:
        rows.extend(wrap_text(line, width))
    return rows


def require_terminal_size(stdscr, width=64, height=18):
    """Render a stable fallback instead of drawing overlapping panels."""
    h, w = stdscr.getmaxyx()
    if w >= width and h >= height:
        return True
    stdscr.erase()
    safe_addstr(stdscr, 1, 2, "Terminal window is too small", ATTR_WARN | curses.A_BOLD)
    safe_addstr(
        stdscr,
        3,
        2,
        f"Resize to at least {width} x {height} (current: {w} x {h}).",
        ATTR_MUTED,
    )
    safe_addstr(stdscr, max(5, h - 2), 2, "q quit", ATTR_SUBTLE)
    stdscr.noutrefresh()
    curses.doupdate()
    return False

def draw_border(win, y, x, h, w, title=""):
    if h < 2 or w < 2:
        return
    safe_addstr(win, y, x, "┌" + "─"*(w-2), ATTR_BORDER)
    if title:
        t = f" {title} "
        tw = text_width(t)
        tx = x + (w - tw) // 2
        safe_addstr(win, y, tx, t, ATTR_SECTION)
        if tx > x + 1:
            safe_addstr(win, y, x+1, "─"*(tx-x-1), ATTR_BORDER)
        if tx + tw < x + w - 1:
            safe_addstr(win, y, tx+tw, "─"*(x+w-1-tx-tw), ATTR_BORDER)
        safe_addstr(win, y, x+w-1, "┐", ATTR_BORDER)
    else:
        safe_addstr(win, y, x+w-1, "┐", ATTR_BORDER)
    for i in range(1, h-1):
        safe_addstr(win, y+i, x, "│", ATTR_BORDER)
        safe_addstr(win, y+i, x+w-1, "│", ATTR_BORDER)
    safe_addstr(win, y+h-1, x, "└" + "─"*(w-2) + "┘", ATTR_BORDER)

def draw_thick_border(win, y, x, h, w, title=""):
    """Draw a thick/rounded-style border (like lipgloss.ThickBorder)."""
    if h < 2 or w < 2:
        return
    safe_addstr(win, y, x, "╭" + "─"*(w-2), ATTR_FOCUS_BORDER)
    if title:
        t = f" {title} "
        tw = text_width(t)
        tx = x + (w - tw) // 2
        safe_addstr(win, y, tx, t, ATTR_SECTION)
        if tx > x + 1:
            safe_addstr(win, y, x+1, "─"*(tx-x-1), ATTR_FOCUS_BORDER)
        if tx + tw < x + w - 1:
            safe_addstr(win, y, tx+tw, "─"*(x+w-1-tx-tw), ATTR_FOCUS_BORDER)
        safe_addstr(win, y, x+w-1, "╮", ATTR_FOCUS_BORDER)
    else:
        safe_addstr(win, y, x+w-1, "╮", ATTR_FOCUS_BORDER)
    for i in range(1, h-1):
        safe_addstr(win, y+i, x, "│", ATTR_FOCUS_BORDER)
        safe_addstr(win, y+i, x+w-1, "│", ATTR_FOCUS_BORDER)
    safe_addstr(win, y+h-1, x, "╰" + "─"*(w-2) + "╯", ATTR_FOCUS_BORDER)

# ── table rendering (shared by wifi-tui, bluetooth-tui) ─────────────────
def space_around(inner_w: int, col_widths: list[int]) -> list[int]:
    """Return x-offsets for columns using CSS/ratatui SpaceAround distribution."""
    n = len(col_widths)
    if n == 0:
        return []
    total = sum(col_widths)
    free = max(0, inner_w - total)
    unit = free / n
    offsets = []
    x = unit / 2.0
    for cw in col_widths:
        offsets.append(int(round(x)))
        x += cw + unit
    return offsets


def clip_cell(s: str, width: int) -> str:
    """Pad/truncate string to display width, best-effort for wide glyphs."""
    if width <= 0:
        return ""
    if len(s) > width:
        return s[: max(0, width - 1)] + "\u2026" if width > 1 else s[:width]
    return s.ljust(width)


def draw_row(win, y: int, x: int, inner_w: int, cells: list[str],
             widths: list[int], offsets: list[int], attr: int):
    """Paint a full-width row: fill bg then place cells at given offsets."""
    try:
        win.addnstr(y, x, " " * inner_w, inner_w, attr)
    except curses.error:
        pass
    for cell, off, cw in zip(cells, offsets, widths):
        text = clip_cell(cell, cw)
        try:
            win.addnstr(y, x + off, text, cw, attr)
        except curses.error:
            pass


def put_row_cells(win, y: int, x: int, inner_w: int, cells: list[str],
                  widths: list[int], attr: int):
    """Same as draw_row but auto-computes SpaceAround offsets."""
    offsets = space_around(inner_w, widths)
    draw_row(win, y, x, inner_w, cells, widths, offsets, attr)


def header_attr(focused: bool) -> int:
    """Table header attribute — section-style regardless of focus."""
    return ATTR_SECTION


def sel_attr(selected: bool, focused_section: bool) -> int:
    """Row selection attribute."""
    if selected and focused_section:
        return ATTR_FOCUS
    return ATTR_TEXT

def draw_lines_in_area(win, y, x, h, w, tagged_lines):
    inner_y = y + 1
    inner_h = h - 2
    inner_w = w - 4
    for i, (tag, text) in enumerate(tagged_lines):
        if i >= inner_h:
            break
        safe_addstr(win, inner_y + i, x + 2, truncate(text, inner_w), TAG_STYLE.get(tag, ATTR_TEXT))

def draw_scrim(win, h, w):
    """Fill the whole screen with a black-on-black scrim so a modal overlay
    stands out from the underlying TUI panels."""
    if h <= 0 or w <= 0:
        return
    try:
        for row in range(h):
            win.addnstr(row, 0, " " * w, w, ATTR_OVERLAY)
    except curses.error:
        pass


def draw_dialog(stdscr, lines, attr=None):
    """Draw a centered overlay dialog.

    *lines* is a list of strings forming the dialog box (including box-drawing
    characters).  The box is centred horizontally and vertically inside the
    terminal; *attr* defaults to ``ATTR_ACCENT_BOLD``.
    """
    if attr is None:
        attr = ATTR_ACCENT_BOLD
    h, w = stdscr.getmaxyx()
    box_h = len(lines)
    box_w = max(text_width(l) for l in lines)
    top = (h - box_h) // 2
    left = max(0, (w - box_w) // 2)
    for i, line in enumerate(lines):
        try:
            stdscr.addnstr(top + i, left, line, min(len(line), w - left), attr)
        except curses.error:
            pass

def draw_log_in_area(win, y, x, h, w, logs, scroll_offset=0, empty_text="(no activity yet)"):
    inner_y = y + 1
    inner_h = h - 2
    inner_w = w - 4
    # Build list of (attr, text) pairs, supporting color-tagged entries
    pair_list = []
    for entry in logs:
        if isinstance(entry, tuple) and len(entry) == 2 and isinstance(entry[0], str) and entry[0] in TAG_STYLE:
            # Color-tagged entry: ("ok", "text"), ("danger", "text"), etc.
            tag, text = entry
            attr = TAG_STYLE[tag]
        else:
            text = str(entry)
            attr = ATTR_MUTED
        for line in wrap_text(text, inner_w):
            pair_list.append((attr, line))
    total = len(pair_list)
    if total == 0:
        safe_addstr(win, inner_y, x + 2, empty_text, ATTR_MUTED)
        return
    start = max(0, total - inner_h - scroll_offset)
    end = min(total, start + inner_h)
    for i, (attr, line) in enumerate(pair_list[start:end]):
        safe_addstr(win, inner_y + i, x + 2, line, attr)
    # scrollbar
    if total > inner_h:
        bar_h = max(1, inner_h * inner_h // total)
        if scroll_offset == 0:
            bar_pos = inner_h - bar_h
        else:
            bar_pos = max(0, inner_h - bar_h - scroll_offset * inner_h // total)
        for i in range(inner_h):
            ch = "┃" if bar_pos <= i < bar_pos + bar_h else "│"
            safe_addstr(win, inner_y + i, x + w - 2, ch, ATTR_SUBTLE)

def help_text(items):
    parts = []
    for k, l in items:
        parts.append(f"{k}: {l}")
    return "  ".join(parts)


def draw_help_bar(stdscr, generic_items, tool_items):
    """Render a two-line context-sensitive help bar.

    Line 1 (row h-2): generic/navigation keys.
    Line 2 (row h-1): tool-specific operations.
    """
    h, _ = stdscr.getmaxyx()
    pad = 2
    if generic_items:
        safe_addstr(stdscr, h - 2, pad, help_text(generic_items), ATTR_SUBTLE)
    if tool_items:
        safe_addstr(stdscr, h - 1, pad, help_text(tool_items), ATTR_SUBTLE)


# ── model ────────────────────────────────────────────────────────────────

class StatusModel:
    """Common model fields for TUI pages backed by a status-command schema.

    Provides ``width``, ``height``, ``status``, ``logs``, ``selected``,
    ``scroll_offset``, ``busy``, ``refreshing``, ``message``, ``err``, and
    ``dirty``.  The ``val()`` / ``boo()`` helpers read the ``status`` dict.
    ``append_log()`` keeps the last 200 lines.
    """
    def __init__(self):
        self.width = 0
        self.height = 0
        self.status = {}
        self.logs = []
        self.selected = 0
        self.scroll_offset = 0
        self.busy = False
        self.refreshing = False
        self.message = ""
        self.err = ""
        self.dirty = True

    def val(self, key, fallback=""):
        return self.status.get(key, fallback)

    def boo(self, key):
        return self.status.get(key) == "true"

    def append_log(self, text):
        self.logs.append(text)
        if len(self.logs) > 200:
            self.logs = self.logs[-200:]
        self.scroll_offset = 0
        self.dirty = True

class RefreshCounter:
    """Simplifies the pending-fetch-counter pattern in StatusModel.refresh().

    Usage::

        rc = RefreshCounter(3, model, on_done=lambda: setattr(model, 'refreshing', False))
        S.run_cmd_bg("cmd1", callback=rc.cb(on_status))
        S.run_cmd_bg("cmd2", callback=rc.cb(on_devices))
        S.run_cmd_bg("cmd3", callback=rc.cb(on_fnmode))

    Each ``.cb(handler)`` returns a ``(lines, err)`` callback that calls
    *handler* (if given), decrements the counter, invokes *on_done* when
    exhausted, and sets ``model.dirty = True``.

    .. note::
        The callback **does not** call ``model.append_log()`` — the handler
        is responsible for any log/error recording.
    """

    def __init__(self, count, model, *, on_done=None):
        self._remaining = count
        self._model = model
        self._on_done = on_done

    def cb(self, handler=None):
        """Return a ``(lines, err)`` callback that matches ``run_cmd_bg``.

        If *handler* is provided it is called **before** the counter is
        decremented so it can read fields set by the handler.
        """
        _remaining = self
        _model = self._model
        _on_done = self._on_done

        def _cb(lines, err):
            if handler:
                handler(lines, err)
            _remaining._remaining -= 1
            if _remaining._remaining <= 0 and _on_done:
                _on_done()
            _model.dirty = True

        return _cb




def finish_frame(stdscr):
    """Mark a frame complete: noutrefresh + doupdate."""
    stdscr.noutrefresh()
    curses.doupdate()


def run_tui_loop(stdscr, model, view, handle_key, *,
                poll_timeout=200,
                refresh_interval=None,
                refresh_callback=None,
                show_cursor=False):
    """Standard curses event loop shared by all settings TUIs.

    - Initialises colours, mouse, ESC delay, cursor visibility.
    - Calls ``view(stdscr, model)`` whenever ``model.dirty`` is set.
    - Polls ``stdscr.getch()`` with ``poll_timeout`` ms and dispatches to
      ``handle_key(stdscr, model, key)`` (return Falsey to exit the loop).
    - Optionally calls ``refresh_callback(model)`` once at least
      ``refresh_interval`` seconds have elapsed since the last refresh.
    - ``poll_timeout`` and ``refresh_interval`` may be numbers or callables
      ``model -> number`` so the cadence can vary with application state
      (e.g. voice trial listening uses a shorter interval).
    - Restores mouse state on exit; ``KeyboardInterrupt`` exits cleanly.
    """
    init_colors()
    enable_mouse()
    if not show_cursor:
        try:
            curses.curs_set(0)
        except curses.error:
            pass
    curses.set_escdelay(1)
    model.dirty = True
    try:
        while True:
            drain_callbacks()
            if model.dirty:
                view(stdscr, model)
                model.dirty = False

            if refresh_callback is not None and refresh_interval is not None:
                ri = refresh_interval(model) if callable(refresh_interval) else refresh_interval
                if ri and ri > 0:
                    now = time.time()
                    last = getattr(model, "last_tick", now)
                    if now - last >= ri:
                        model.last_tick = now
                        refresh_callback(model)

            pt = poll_timeout(model) if callable(poll_timeout) else poll_timeout
            stdscr.timeout(max(1, int(pt)))

            key = stdscr.getch()
            if key == -1:
                continue
            if not handle_key(stdscr, model, key):
                break
    except KeyboardInterrupt:
        pass
    finally:
        disable_mouse()


def two_column_widths(content_w, *, left_w=34, right_min=28, gap=0):
    """Resolve (left_w, right_w) for the standard two-column settings layout.

    Guarantees the right column is at least ``right_min`` columns wide;
    shrinks the left column (down to a floor of 22) when space is tight.
    Returns ``(content_w, 0)`` when there is no room for two columns.
    """
    if left_w < 22:
        left_w = 22
    right_w = content_w - left_w - gap
    if right_w < right_min:
        right_w = max(right_min, content_w - max(22, content_w - right_min) - gap)
        left_w = max(22, content_w - right_w - gap)
    if right_w < right_min:
        return content_w, 0
    return left_w, right_w


def draw_focus_border(stdscr, focused, y, x, h, w, title=""):
    """Border that uses the thick/rounded style when the panel is focused."""
    if focused:
        draw_thick_border(stdscr, y, x, h, w, title)
    else:
        draw_border(stdscr, y, x, h, w, title)

# ── visual primitives (port of Go ui/*.go) ────────────────────────────────

def status_attr(tone):
    """Return text attribute based on tone."""
    return {
        "ok": ATTR_OK_BOLD,
        "warn": ATTR_WARN,
        "danger": ATTR_DANGER,
        "muted": ATTR_MUTED,
    }.get(tone, ATTR_MUTED)

def section_title(text):
    return ("section", text)

def hero_line(title, subtitle, tone="ok", busy=False, message="", status_text=""):
    """Build hero block: Title [working…|message]\nsubtitle  [status]

    status_text: right-aligned status label (empty = no status shown)
    tone: color for status_text
    """
    title_attr = ATTR_TEXT | curses.A_BOLD
    msg = ""
    msg_attr = 0
    if busy:
        msg = " working…"
        msg_attr = ATTR_OK
    elif message:
        msg_attr = {
            "ok": ATTR_OK, "warn": ATTR_WARN, "danger": ATTR_DANGER,
        }.get(tone, ATTR_ACCENT_BOLD)
        msg = f" {message}"
    st_attr = status_attr(tone)
    if status_text:
        status_text = "● " + status_text
    return (title, title_attr, msg, msg_attr, subtitle, status_text, st_attr)


def draw_hero(stdscr, hero_tuple):
    """Render the standard 2-row hero block produced by hero_line().

    Layout (rows 0-1):
        Title [message]                              ● Status
        subtitle
    """
    title, ta, msg, ma, sub, status_text, sa = hero_tuple
    pad = 2
    # Title + message on the left
    x = pad
    safe_addstr(stdscr, 0, x, title, ta)
    x += text_width(title)
    if msg:
        safe_addstr(stdscr, 0, x, msg, ma)
        x += text_width(msg)
    # Status text on the right
    if status_text:
        _, w = stdscr.getmaxyx()
        right_x = w - pad - text_width(status_text)
        if right_x > x + 1:
            safe_addstr(stdscr, 0, right_x, status_text, sa)
    safe_addstr(stdscr, 1, pad, sub, ATTR_MUTED)
def primary_line(label, key="enter", enabled=True):
    """→ Label (key) — main CTA."""
    if enabled:
        return ("primary", f"→ {label} ({key})")
    return ("muted", f"  {label} ({key})")

def action_line(key, label, enabled=True):
    """Label (key) — secondary action."""
    if enabled:
        return ("action", f"{label} ({key})")
    return ("muted", f"{label} ({key})")

def danger_action_line(key, label, enabled=True):
    """Label (key) — destructive action."""
    if enabled:
        return ("danger_action", f"{label} ({key})")
    return ("muted", f"{label} ({key})")

def toggle_line(on, label, focused=False, dimmed=False, trailing=""):
    """[X] Label  trailing"""
    box = "[X]" if on else "[ ]"
    if dimmed:
        tag = "muted"
    elif focused:
        tag = "focus"
    else:
        tag = "text"
    text = f"{box} {label}"
    if trailing:
        text += f"  {trailing}"
    return (tag, text)

def cycle_line(label, value, key="", focused=False):
    """Label: value (key)"""
    if focused:
        tag = "focus"
        return (tag, f"{label}: {value} ({key})")
    return ("text", f"{label}: {value} ({key})")

def segmented_line(label, options, selected=0, focused=False):
    """Label: [opt1] · opt2 · opt3"""
    parts = []
    for i, opt in enumerate(options):
        if i == selected:
            parts.append(f"[{opt}]")
        else:
            parts.append(opt)
    return ("text" if not focused else "focus", f"{label}: " + " · ".join(parts))

def kv_line(label, value, width=48):
    """Label  value (right-aligned)"""
    if width < 12:
        width = 12
    gap = 2
    remain = width - text_width(label) - gap
    if remain < 4:
        remain = 4
    clipped = truncate(value, remain)
    padding = max(gap, width - text_width(label) - text_width(clipped))
    return ("text", f"{label}{' '*padding}{clipped}")

def profile_enabled_line(on, focused=False):
    """Profile: [X] Enabled"""
    box = "[X]" if on else "[ ]"
    tag = "focus" if focused else "text"
    return (tag, f"Profile: {box} Enabled")

def pending_line(apply_key="a", discard_key="x"):
    return ("ok", f"Pending changes · Apply ({apply_key}) · Discard ({discard_key})")

def progress_bar(percent, width=20):
    """█…░… bar"""
    width = max(4, width)
    percent = max(0, min(100, percent))
    filled = percent * width // 100
    return "█" * filled + "░" * (width - filled)

def format_duration(sec):
    """MM:SS"""
    return f"{sec//60:02d}:{sec%60:02d}"

def parse_int(raw):
    try:
        return int(raw.strip())
    except (ValueError, AttributeError):
        return 0

def clip_lines(lines, count):
    if count <= 0 or not lines:
        return []
    if len(lines) <= count:
        return lines
    return lines[-count:]

def expand_path(path):
    """Expand ~ and env vars in a filesystem path."""
    if not path:
        return ""
    return os.path.expanduser(os.path.expandvars(path))

def setup_locale():
    """Set LC_ALL/LANG defaults and narrow ambiguous-width handling.

    Call near the top of ``main()`` in every TUI that uses box-drawing
    characters — prevents CJK locales from treating them as double-width.
    Must run before ``curses.initscr()``.
    """
    for loc in ("C.UTF-8", "en_US.UTF-8", "C"):
        try:
            locale.setlocale(locale.LC_CTYPE, loc)
            break
        except locale.Error:
            continue
    os.environ.setdefault("LC_ALL", "C.UTF-8")
    os.environ.setdefault("LANG", "C.UTF-8")

# ── mouse helpers ─────────────────────────────────────────────────────────
def enable_mouse():
    try:
        curses.mousemask(curses.ALL_MOUSE_EVENTS | curses.REPORT_MOUSE_POSITION)
    except curses.error:
        pass

def disable_mouse():
    try:
        curses.mousemask(0)
    except curses.error:
        pass

def get_mouse_event():
    """Return (x, y, button, kind) or None."""
    try:
        _, mx, my, _, bstate = curses.getmouse()
        # Wheel events must be handled before click detection.
        if bstate & curses.BUTTON4_PRESSED:
            return (mx, my, "wheel", "up")
        if bstate & curses.BUTTON5_PRESSED:
            return (mx, my, "wheel", "down")
        # Determine button
        button = "left"
        if bstate & curses.BUTTON2_CLICKED or bstate & curses.BUTTON2_PRESSED or bstate & curses.BUTTON2_RELEASED:
            button = "middle"
        elif bstate & curses.BUTTON3_CLICKED or bstate & curses.BUTTON3_PRESSED or bstate & curses.BUTTON3_RELEASED:
            button = "right"
        # Determine kind
        if bstate & curses.BUTTON1_PRESSED or bstate & curses.BUTTON2_PRESSED or bstate & curses.BUTTON3_PRESSED:
            kind = "press"
        elif bstate & curses.BUTTON1_RELEASED or bstate & curses.BUTTON2_RELEASED or bstate & curses.BUTTON3_RELEASED:
            kind = "release"
        elif bstate & curses.REPORT_MOUSE_POSITION:
            kind = "move"
        else:
            kind = "click"
        return (mx, my, button, kind)
    except curses.error:
        return None

def mouse_wheel_delta(me, step=3):
    """Return scroll delta for wheel events, or None."""
    if not me:
        return None
    _x, _y, button, kind = me
    if button != "wheel":
        return None
    if kind == "up":
        return step
    if kind == "down":
        return -step
    return None

def scroll_key(key, scroll_offset, *, page_size=10, max_offset=None):
    """Process scroll-related key presses and return ``(delta, new_offset)``.

    Handles ``KEY_UP`` (increase offset), ``KEY_DOWN`` (decrease),
    ``KEY_PPAGE`` (page up), ``KEY_NPAGE`` (page down), ``KEY_HOME`` (max),
    and ``KEY_END`` (zero).  Returns ``(delta, new_offset)`` on match or
    ``None`` if *key* is not a scroll key.

    Usage::

        r = S.scroll_key(key, model.scroll_offset)
        if r is not None:
            delta, model.scroll_offset = r
            model.dirty = True
            return True
    """
    if key in (curses.KEY_UP, ord('k')):
        delta = page_size
        new_val = scroll_offset + delta
    elif key in (curses.KEY_DOWN, ord('j')):
        delta = -page_size
        new_val = max(0, scroll_offset - page_size)
    elif key == curses.KEY_PPAGE:
        delta = page_size * 3
        new_val = scroll_offset + page_size * 3
    elif key == curses.KEY_NPAGE:
        delta = -(page_size * 3)
        new_val = max(0, scroll_offset - page_size * 3)
    elif key == curses.KEY_HOME:
        delta = 999999
        new_val = delta
    elif key == curses.KEY_END:
        delta = -scroll_offset
        new_val = 0
    else:
        return None
    if max_offset is not None:
        new_val = min(new_val, max_offset)
    return delta, new_val

def hit_test(plain_lines, click_x, click_y, text):
    """Check if click_x,click_y falls within text in plain_lines at click_y."""
    if click_y < 0 or click_y >= len(plain_lines):
        return False
    line = plain_lines[click_y]
    if click_x < 0 or click_x >= text_width(line):
        return False
    idx = line.find(text)
    if idx < 0:
        return False
    start = text_width(line[:idx])
    end = start + text_width(text)
    return start - 2 <= click_x <= end + 2

def strip_ansi(text):
    """Remove ANSI escape sequences from text."""
    import re
    return re.sub(r'\x1b\[[0-9;]*[a-zA-Z]', '', text)

def get_plain_lines(stdscr):
    """Get the current screen content as plain text lines."""
    h, w = stdscr.getmaxyx()
    lines = []
    for y in range(h):
        try:
            raw = stdscr.instr(y, 0, w)
            encoding = getattr(stdscr, "encoding", None) or "utf-8"
            lines.append(raw.decode(encoding, errors="replace"))
        except curses.error:
            lines.append("")
    return lines

# ── layout template ─────────────────────────────────────────────────────

class Layout:
    """Standard two-panel layout for Sumika settings TUIs.

    Creates a consistent screen partition every TUI follows:
    hero header -> left/right content panels -> help bar.

    Customize by overriding these attributes before ``compute()``:

    * ``pad`` (2) — horizontal & vertical screen margin
    * ``hero_h`` (2) — hero banner height
    * ``help_h`` (1) — help bar height
    * ``gap`` (1) — gap between left/right panels
    * ``left_w`` (34) — left panel width
    * ``right_min`` (28) — minimum right panel width
    * ``split_threshold`` (80) — minimum terminal width to show two panels
    * ``force_single`` (False) — force single-column even when wide enough

    After ``compute()`` the following are populated:

    * ``content_top``, ``content_h``, ``content_w`` — content area
    * ``show_right`` — whether right panel is visible
    * ``left_x/y/h/w``, ``right_x/y/h/w`` — panel rectangles

    Usage in ``_view()``::

        ly = S.Layout(stdscr)
        ly.force_single = True    # single-column mode
        ly.compute()
        ly.draw_hero(stdscr, hero_lines)
        ly.draw_panel("left", "Settings", settings_lines, focus=True)
        ...
        ly.draw_help(stdscr, *help_items(m))
    """

    __slots__ = (
        "stdscr", "h", "w",
        "pad", "hero_h", "help_h", "gap",
        "left_w", "right_min", "split_threshold", "force_single",
        "content_top", "content_h", "content_w",
        "show_right",
        "left_x", "left_y", "left_h", "left_right_x",
        "right_x", "right_y", "right_w", "right_h",
    )

    def __init__(self, stdscr):
        self.stdscr = stdscr
        self.h, self.w = stdscr.getmaxyx()
        # defaults (override before calling compute())
        self.pad = 2
        self.hero_h = 2
        self.help_h = 2
        self.gap = 1
        self.left_w = 34
        self.right_min = 28
        self.split_threshold = 80
        self.force_single = False

    def compute(self):
        """Calculate all geometry from current terminal size and parameters."""
        h, w = self.h, self.w
        self.content_top = self.hero_h + self.pad
        self.content_w = w - 2 * self.pad
        self.content_h = h - self.content_top - self.help_h

        if self.force_single or self.content_w < self.left_w + self.gap + self.right_min:
            self.show_right = False
            self.left_w = self.content_w      # expand to fill
        else:
            self.show_right = True
            rw = self.content_w - self.left_w - self.gap
            self.right_w = max(self.right_min, rw)
            self.right_x = self.pad + self.left_w + self.gap
            self.right_y = self.content_top
            self.right_h = self.content_h

        self.left_y = self.content_top
        self.left_x = self.pad
        self.left_h = self.content_h

    # -- drawing helpers --------------------------------------------------

    @staticmethod
    def draw_hero(stdscr, hero_data):
        """Draw hero header at the top of the screen."""
        import sumika_tui_framework as _S
        _S.draw_hero(stdscr, hero_data)

    @staticmethod
    def draw_help(stdscr, generic, tool):
        """Draw help bar at the bottom of the screen."""
        draw_help_bar(stdscr, generic, tool)

    def _draw_box(self, y, x, h, w, title, focus):
        if focus:
            draw_thick_border(self.stdscr, y, x, h, w, title)
        else:
            draw_border(self.stdscr, y, x, h, w, title)

    def draw_panel(self, side, title, tagged_lines, *, focus=False):
        """Draw a bordered panel with tagged content lines.

        *side* is ``"left"`` or ``"right"``.  Does nothing for ``"right"``
        when *show_right* is False.
        """
        if side == "left":
            y, x, h, w = self.left_y, self.left_x, self.left_h, self.left_w
        elif side == "right":
            if not self.show_right:
                return
            y, x, h, w = self.right_y, self.right_x, self.right_h, self.right_w
        else:
            raise ValueError(f"Layout.draw_panel: unknown side {side!r}")

        self._draw_box(y, x, h, w, title, focus)
        draw_lines_in_area(self.stdscr, y, x, h, w, tagged_lines)

    def inner_rect(self, side):
        """Return ``(y, x, h, w)`` of the *text area* inside a panel."""
        if side == "left":
            y, x, h, w = self.left_y, self.left_x, self.left_h, self.left_w
        elif side == "right":
            if not self.show_right:
                return (0, 0, 0, 0)
            y, x, h, w = self.right_y, self.right_x, self.right_h, self.right_w
        else:
            raise ValueError(f"Layout.inner_rect: unknown side {side!r}")
        return (y + 1, x + 2, h - 2, w - 4)


def handle_tab(key, model, field="focus", count=2):
    """Process Tab key -> cycle *field* on *model* between 0 .. *count*-1.

    Returns ``True`` when Tab was consumed.  Typical usage in ``handle_key``::

        if S.handle_tab(key, m):
            return True
    """
    if key == ord("\t"):
        cur = getattr(model, field, 0)
        setattr(model, field, (cur + 1) % count)
        model.dirty = True
        return True
    return False



# ── image preview (half-block + quadrant rendering) ───────────────────────
# Provides a reusable terminal image preview for TUIs that need to show
# wallpaper/artwork thumbnails. Supports PIL (half-block) and ImageMagick
# (quadrant) backends, with a dynamic color-pair pool for 256-color terminals.

_QUADRANT_CHARS = {
    0x0: " ", 0x1: "▘", 0x2: "▝", 0x3: "▀",
    0x4: "▖", 0x5: "▌", 0x6: "▞", 0x7: "▛",
    0x8: "▗", 0x9: "▚", 0xA: "▐", 0xB: "▜",
    0xC: "▄", 0xD: "▙", 0xE: "▟", 0xF: "█",
}

_C_IMG_BASE = 11
_MAX_IMG_PAIRS = 240
_color_pair_map = {}
_next_pair_idx = [_C_IMG_BASE]
_image_preview_cache = {"path": "", "width": 0, "height": 0, "mtime": 0, "size": 0, "view": ""}


def _distance_sq(a, b):
    return sum((a[i] - b[i]) ** 2 for i in range(3))


def _average_rgb(colors):
    if not colors:
        return (0, 0, 0)
    count = len(colors)
    return tuple(round(sum(color[i] for color in colors) / count) for i in range(3))


def _quadrant_cell(pixels):
    """Reduce four RGB pixels to a two-color Unicode quadrant cell."""
    first = pixels[0]
    second = max(pixels[1:], key=lambda c: _distance_sq(first, c))
    foreground, background = first, second
    assignments = [False] * 4
    for _ in range(3):
        assignments = [
            _distance_sq(p, foreground) <= _distance_sq(p, background)
            for p in pixels
        ]
        fg = [p for p, a in zip(pixels, assignments) if a]
        bg = [p for p, a in zip(pixels, assignments) if not a]
        if fg:
            foreground = _average_rgb(fg)
        if bg:
            background = _average_rgb(bg)
    mask = sum(1 << i for i, a in enumerate(assignments) if a)
    if mask == 0xF:
        background = foreground
        mask = 0
    return (_QUADRANT_CHARS[mask], *foreground, *background)


def _closest_image_pair(r_fg, g_fg, b_fg, r_bg, g_bg, b_bg):
    if not _color_pair_map:
        return 0
    req_fg = (r_fg, g_fg, b_fg)
    req_bg = (r_bg, g_bg, b_bg)
    key = min(
        _color_pair_map,
        key=lambda p: _distance_sq(req_fg, _xterm_rgb(p[0]))
                     + _distance_sq(req_bg, _xterm_rgb(p[1])),
    )
    return _color_pair_map[key]


def _get_image_color_pair(r_fg, g_fg, b_fg, r_bg, g_bg, b_bg):
    fi = _nearest_xterm_index(r_fg, g_fg, b_fg)
    bi = _nearest_xterm_index(r_bg, g_bg, b_bg)
    key = (fi, bi)
    if key in _color_pair_map:
        return _color_pair_map[key]
    lim = min(_C_IMG_BASE + _MAX_IMG_PAIRS, max(_C_IMG_BASE, getattr(curses, "COLOR_PAIRS", 0)))
    if getattr(curses, "COLORS", 0) < 256 or _next_pair_idx[0] >= lim:
        return _closest_image_pair(r_fg, g_fg, b_fg, r_bg, g_bg, b_bg)
    pid = _next_pair_idx[0]
    _next_pair_idx[0] += 1
    try:
        curses.init_pair(pid, fi, bi)
    except curses.error:
        return 0
    _color_pair_map[key] = pid
    return pid


def _render_image_preview(path, width, height):
    """Render an image file as half-block Unicode characters.
    Falls back to ImageMagick quadrant approach when PIL is unavailable.
    Returns a list of rows; each row is a list of (char, r_fg, g_fg, b_fg, r_bg, g_bg, b_bg) tuples.
    """
    global _image_preview_cache
    if not path or width <= 0 or height <= 0:
        return []
    try:
        mtime = os.path.getmtime(path)
        fsize = os.path.getsize(path)
    except OSError:
        return []
    if (_image_preview_cache["path"] == path and
            _image_preview_cache["width"] == width and
            _image_preview_cache["height"] == height and
            _image_preview_cache["mtime"] == mtime and
            _image_preview_cache["size"] == fsize):
        return _image_preview_cache["view"]
    if _image_preview_cache["path"] != path:
        _color_pair_map.clear()
        _next_pair_idx[0] = _C_IMG_BASE
    try:
        from PIL import Image
        img = Image.open(path).convert("RGB")
        src_w, src_h = img.size
        if src_w <= 0 or src_h <= 0:
            return []
        sw, sh = width, height * 2
        ta = sw / sh
        ia = src_w / src_h
        if ia > ta:
            nw = int(src_h * ta)
            ox = (src_w - nw) // 2
            ic = img.crop((ox, 0, ox + nw, src_h))
        else:
            nh = int(src_w / ta)
            oy = (src_h - nh) // 2
            ic = img.crop((0, oy, src_w, oy + nh))
        rs = (Image.Resampling.LANCZOS if hasattr(Image, "Resampling")
               else getattr(Image, "ANTIALIAS", Image.BICUBIC))
        ir = ic.resize((sw, sh), rs)
        rows = []
        for row in range(height):
            cols = []
            ty = row * 2
            by = row * 2 + 1
            for col in range(width):
                tp = ir.getpixel((col, ty))
                bp = ir.getpixel((col, by))
                cols.append(("▀", *tp, *bp))
            rows.append(cols)
        _image_preview_cache = {"path": path, "width": width, "height": height,
                                "mtime": mtime, "size": fsize, "view": rows}
        return rows
    except ImportError:
        return _render_image_preview_via_magick(path, width, height)
    except Exception:
        return []


def _render_image_preview_via_magick(path, width, height):
    """Fallback: ImageMagick + quadrant chars when PIL is unavailable."""
    global _image_preview_cache
    try:
        mtime = os.path.getmtime(path)
        fsize = os.path.getsize(path)
    except OSError:
        return []
    try:
        import struct, subprocess
        sw, sh = width * 2, height * 2
        raw = subprocess.check_output(
            ["magick", path, "-resize", f"{sw}x{sh}!", "-depth", "8", "rgb:-"],
            timeout=10,
        )
    except Exception:
        return []
    expected = sw * sh * 3
    if len(raw) < expected:
        return []
    pixels = struct.unpack(f"{sw*sh*3}B", raw[:expected])
    rows = []
    for ri in range(height):
        cols = []
        for ci in range(width):
            sx, sy = ci * 2, ri * 2
            quad = []
            for dy in range(2):
                for dx in range(2):
                    pi = ((sy + dy) * sw + (sx + dx)) * 3
                    if pi + 2 < len(pixels):
                        quad.append((pixels[pi], pixels[pi + 1], pixels[pi + 2]))
            if len(quad) == 4:
                cols.append(_quadrant_cell(quad))
        if len(cols) == width:
            rows.append(cols)
    _image_preview_cache = {"path": path, "width": width, "height": height,
                            "mtime": mtime, "size": fsize, "view": rows}
    return rows


def hex_to_rgb(hex6):
    """Parse a hex color string (#RRGGBB or RRGGBB) to an (r, g, b) tuple."""
    h = hex6.lstrip("#")
    if len(h) != 6:
        return None
    try:
        return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))
    except ValueError:
        return None


def draw_image_preview(stdscr, path, y, x, w, h):
    """Render an image file at (y, x) with size (w, h) in terminal cells.

    Uses half-block (PIL) or quadrant (ImageMagick) rendering with a dynamic
    256-color pair pool. Safe to call every frame — results are cached by
    path + size + mtime.

    Returns True if the image was rendered, False if it failed or path is empty.
    """
    if not path or w <= 0 or h <= 0:
        return False
    if path.startswith("~/"):
        path = os.path.expanduser(path)
    rows = _render_image_preview(path, w, h)
    if not rows:
        return False
    for ri, row in enumerate(rows):
        for ci, px in enumerate(row):
            if len(px) != 7:
                continue
            ch, *rgb = px
            pid = _get_image_color_pair(*rgb)
            safe_addstr(stdscr, y + ri, x + ci, ch, curses.color_pair(pid))
    return True


def draw_color_swatch(stdscr, y, x, w, h, hex_color):
    """Fill a rectangular area with a solid color from a hex string.

    Uses xterm-256 color pairs.  Safe to call every frame.
    """
    rgb = hex_to_rgb(hex_color) or (0, 0, 0)
    idx = _nearest_xterm_index(*rgb)
    try:
        curses.init_pair(9, idx, idx)
        attr = curses.color_pair(9)
    except curses.error:
        attr = 0
    for row in range(h):
        safe_addstr(stdscr, y + row, x, " " * w, attr)
