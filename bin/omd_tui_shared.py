#!/usr/bin/env python3
"""Shared helpers for Python curses settings TUIs.

Port of tui-go/internal/ui/*.go — provides the same visual primitives
(PrimaryLine, ActionLine, ToggleLine, CycleLine, SegmentedLine, KVLine,
Hero, SectionTitle, StatusDot, ProgressBar, etc.) so each Python TUI can
render identically to the Go version.
"""

import curses
import os
import queue
import subprocess
import threading
import time
import unicodedata

OMD_ROOT = os.environ.get("OMD_ROOT", os.path.expanduser("~/development/OMD"))

# ── colour pairs ─────────────────────────────────────────────────────────
C_BG, C_FG, C_ACCENT, C_MUTED = 0, 1, 2, 3
C_OK, C_WARN, C_DANGER, C_SECTION = 4, 5, 6, 7
C_BORDER, C_SUBTLE, C_PANEL = 8, 9, 10
# Extended pairs for theme swatches (11..30 allocated at runtime)
C_THEME_START = 11
C_FOCUS_BORDER = 31

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
        path = os.path.join(OMD_ROOT, "current", "theme", "quickshell.json")
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
        path = os.path.join(OMD_ROOT, "current", "theme", "colors.toml")
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
    global C_FOCUS_BORDER
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
TAG_STYLE    = {}

# ── backend ──────────────────────────────────────────────────────────────
def run_cmd(name, *args):
    # If name is an absolute path, use it directly; otherwise look in OMD_ROOT/bin/
    if os.path.isabs(name):
        path = name
    else:
        path = os.path.join(OMD_ROOT, "bin", name)
    try:
        r = subprocess.run(
            [path, *args], stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            text=True, errors="replace", timeout=15, cwd=OMD_ROOT,
        )
        lines = [line for line in r.stdout.splitlines() if line]
        error = "" if r.returncode == 0 else f"exit {r.returncode}"
        return lines, error
    except Exception as e:
        return [str(e)], str(e)

def run_cmd_bg(name, *args, callback=None):
    def _w():
        lines, err = run_cmd(name, *args)
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

def draw_lines_in_area(win, y, x, h, w, tagged_lines):
    inner_y = y + 1
    inner_h = h - 2
    inner_w = w - 4
    for i, (tag, text) in enumerate(tagged_lines):
        if i >= inner_h:
            break
        safe_addstr(win, inner_y + i, x + 2, truncate(text, inner_w), TAG_STYLE.get(tag, ATTR_TEXT))

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
