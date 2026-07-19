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
import unicodedata

OMD_ROOT = os.environ.get("OMD_ROOT", os.path.expanduser("~/development/OMD"))

# ── colour pairs ─────────────────────────────────────────────────────────
C_BG, C_FG, C_ACCENT, C_MUTED = 0, 1, 2, 3
C_OK, C_WARN, C_DANGER, C_SECTION = 4, 5, 6, 7
C_BORDER, C_SUBTLE, C_PANEL = 8, 9, 10
# Extended pairs for theme swatches (11..30 allocated at runtime)
C_THEME_START = 11

_callback_queue = queue.SimpleQueue()

def init_colors():
    global ATTR_SECTION, ATTR_FOCUS, ATTR_OK, ATTR_WARN, ATTR_DANGER
    global ATTR_ACTION, ATTR_MUTED, ATTR_SUBTLE, ATTR_TEXT, ATTR_BORDER, TAG_STYLE
    global ATTR_PRIMARY, ATTR_DANGER_ACTION, ATTR_OK_BOLD, ATTR_ACCENT_BOLD
    if not curses.has_colors():
        return
    curses.start_color()
    try:
        curses.use_default_colors()
    except curses.error:
        pass
    bg = -1
    curses.init_pair(C_FG,      curses.COLOR_WHITE,  bg)
    curses.init_pair(C_ACCENT,  curses.COLOR_CYAN,   bg)
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
    ATTR_WARN    = attr(C_WARN)
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
    safe_addstr(win, y, x, "╭" + "─"*(w-2), ATTR_ACCENT_BOLD)
    if title:
        t = f" {title} "
        tw = text_width(t)
        tx = x + (w - tw) // 2
        safe_addstr(win, y, tx, t, ATTR_SECTION)
        if tx > x + 1:
            safe_addstr(win, y, x+1, "─"*(tx-x-1), ATTR_ACCENT_BOLD)
        if tx + tw < x + w - 1:
            safe_addstr(win, y, tx+tw, "─"*(x+w-1-tx-tw), ATTR_ACCENT_BOLD)
        safe_addstr(win, y, x+w-1, "╮", ATTR_ACCENT_BOLD)
    else:
        safe_addstr(win, y, x+w-1, "╮", ATTR_ACCENT_BOLD)
    for i in range(1, h-1):
        safe_addstr(win, y+i, x, "│", ATTR_ACCENT_BOLD)
        safe_addstr(win, y+i, x+w-1, "│", ATTR_ACCENT_BOLD)
    safe_addstr(win, y+h-1, x, "╰" + "─"*(w-2) + "╯", ATTR_ACCENT_BOLD)

def draw_lines_in_area(win, y, x, h, w, tagged_lines):
    inner_y = y + 1
    inner_h = h - 2
    inner_w = w - 4
    for i, (tag, text) in enumerate(tagged_lines):
        if i >= inner_h:
            break
        safe_addstr(win, inner_y + i, x + 2, truncate(text, inner_w), TAG_STYLE.get(tag, ATTR_TEXT))

def draw_log_in_area(win, y, x, h, w, logs, scroll_offset=0):
    inner_y = y + 1
    inner_h = h - 2
    inner_w = w - 4
    wrapped = []
    for line in logs:
        wrapped.extend(wrap_text(line, inner_w))
    total = len(wrapped)
    if total == 0:
        safe_addstr(win, inner_y, x + 2, "(no activity yet)", ATTR_MUTED)
        return
    start = max(0, total - inner_h - scroll_offset)
    end = min(total, start + inner_h)
    for i, line in enumerate(wrapped[start:end]):
        safe_addstr(win, inner_y + i, x + 2, line, ATTR_MUTED)
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

# ── visual primitives (port of Go ui/*.go) ────────────────────────────────

def status_dot(tone):
    """● health indicator. tone: 'ok', 'warn', 'danger', 'muted'."""
    mapping = {
        "ok": ATTR_OK_BOLD,
        "warn": ATTR_WARN,
        "danger": ATTR_DANGER,
        "muted": ATTR_MUTED,
    }
    return ("●", mapping.get(tone, ATTR_MUTED))

def section_title(text):
    return ("section", text)

def hero_line(title, subtitle, tone="ok", busy=False, message=""):
    """Build hero block: ● Title [working…|message]\\nsubtitle"""
    dot, dot_attr = status_dot(tone)
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
    return (dot, dot_attr, title, title_attr, msg, msg_attr, subtitle)

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
