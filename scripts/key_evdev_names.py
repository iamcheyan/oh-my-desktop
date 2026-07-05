"""Map GTK/XKB hardware keycodes to keyd/evdev key names.

GTK and Hyprland report XKB keycodes (evdev scancode + 8). GDK keyvals can
differ from the physical key under JP or other layouts (e.g. minila 全角/半角
shows ZENKAKU_HANKAKU in GDK but evdev/keyd sees grave).
"""

from __future__ import annotations

# evdev code -> (primary symbol, preferred keyd alt name)
# Derived from keyd t/keys.py
_EVDEV_KEYS: dict[int, tuple[str, str]] = {
    1: ("esc", "escape"),
    2: ("1", ""),
    3: ("2", ""),
    4: ("3", ""),
    5: ("4", ""),
    6: ("5", ""),
    7: ("6", ""),
    8: ("7", ""),
    9: ("8", ""),
    10: ("9", ""),
    11: ("0", ""),
    12: ("-", "minus"),
    13: ("=", "equal"),
    14: ("backspace", ""),
    15: ("tab", ""),
    16: ("q", ""),
    17: ("w", ""),
    18: ("e", ""),
    19: ("r", ""),
    20: ("t", ""),
    21: ("y", ""),
    22: ("u", ""),
    23: ("i", ""),
    24: ("o", ""),
    25: ("p", ""),
    26: ("[", "leftbrace"),
    27: ("]", "rightbrace"),
    28: ("enter", ""),
    29: ("control", "leftcontrol"),
    30: ("a", ""),
    31: ("s", ""),
    32: ("d", ""),
    33: ("f", ""),
    34: ("g", ""),
    35: ("h", ""),
    36: ("j", ""),
    37: ("k", ""),
    38: ("l", ""),
    39: (";", "semicolon"),
    40: ("'", "apostrophe"),
    41: ("`", "grave"),
    42: ("shift", "leftshift"),
    43: ("\\", "backslash"),
    44: ("z", ""),
    45: ("x", ""),
    46: ("c", ""),
    47: ("v", ""),
    48: ("b", ""),
    49: ("n", ""),
    50: ("m", ""),
    51: (",", "comma"),
    52: (".", "dot"),
    53: ("/", "slash"),
    54: ("rightshift", ""),
    55: ("kpasterisk", ""),
    56: ("alt", "leftalt"),
    57: ("space", ""),
    58: ("capslock", ""),
    59: ("f1", ""),
    60: ("f2", ""),
    61: ("f3", ""),
    62: ("f4", ""),
    63: ("f5", ""),
    64: ("f6", ""),
    65: ("f7", ""),
    66: ("f8", ""),
    67: ("f9", ""),
    68: ("f10", ""),
    69: ("numlock", ""),
    70: ("scrolllock", ""),
    71: ("kp7", ""),
    72: ("kp8", ""),
    73: ("kp9", ""),
    74: ("kpminus", ""),
    75: ("kp4", ""),
    76: ("kp5", ""),
    77: ("kp6", ""),
    78: ("kpplus", ""),
    79: ("kp1", ""),
    80: ("kp2", ""),
    81: ("kp3", ""),
    82: ("kp0", ""),
    83: ("kpdot", ""),
    85: ("zenkakuhankaku", ""),
    86: ("102nd", ""),
    87: ("f11", ""),
    88: ("f12", ""),
    89: ("ro", ""),
    90: ("katakana", ""),
    91: ("hiragana", ""),
    92: ("henkan", ""),
    93: ("katakanahiragana", ""),
    94: ("muhenkan", ""),
    95: ("kpjpcomma", ""),
    96: ("kpenter", ""),
    97: ("rightcontrol", ""),
    98: ("kpslash", ""),
    99: ("sysrq", ""),
    100: ("rightalt", ""),
    101: ("linefeed", ""),
    102: ("home", ""),
    103: ("up", ""),
    104: ("pageup", ""),
    105: ("left", ""),
    106: ("right", ""),
    107: ("end", ""),
    108: ("down", ""),
    109: ("pagedown", ""),
    110: ("insert", ""),
    111: ("delete", ""),
    113: ("mute", ""),
    114: ("volumedown", ""),
    115: ("volumeup", ""),
    116: ("power", ""),
    119: ("pause", ""),
    125: ("meta", "leftmeta"),
    126: ("rightmeta", ""),
    127: ("compose", ""),
    163: ("nextsong", ""),
    164: ("playpause", ""),
    165: ("previoussong", ""),
    166: ("stopcd", ""),
    173: ("refresh", ""),
    183: ("f13", ""),
    184: ("f14", ""),
    185: ("f15", ""),
    186: ("f16", ""),
    187: ("f17", ""),
    188: ("f18", ""),
    189: ("f19", ""),
    190: ("f20", ""),
    191: ("f21", ""),
    192: ("f22", ""),
    193: ("f23", ""),
    194: ("f24", ""),
    210: ("print", ""),
    224: ("brightnessdown", ""),
    225: ("brightnessup", ""),
    248: ("micmute", ""),
    464: ("fn", ""),
    465: ("fnesc", ""),
}

_KEYD_ALIASES = {
    "escape": "esc",
    "control": "leftcontrol",
    "shift": "leftshift",
    "alt": "leftalt",
    "meta": "leftmeta",
    "print": "printscreen",
    "sysrq": "printscreen",
    "kpenter": "enter",
}


def gtk_keycode_to_evdev(gtk_keycode: int | None) -> int | None:
    if gtk_keycode is None or gtk_keycode < 9:
        return None
    return gtk_keycode - 8


def _pick_keyd_name(primary: str, alt: str) -> str | None:
    alt = (alt or "").strip()
    primary = (primary or "").strip()
    if alt and alt.isidentifier():
        return alt
    if primary and primary.isidentifier():
        return primary
    if alt:
        return alt
    if primary and len(primary) == 1 and primary.isalnum():
        return primary
    return primary or None


def evdev_to_keyd(evdev_code: int | None) -> str | None:
    if evdev_code is None:
        return None
    entry = _EVDEV_KEYS.get(evdev_code)
    if not entry:
        return None
    raw = _pick_keyd_name(entry[0], entry[1])
    if not raw:
        return None
    raw = raw.lower()
    return _KEYD_ALIASES.get(raw, raw)


def gtk_keycode_to_keyd(gtk_keycode: int | None) -> str | None:
    return evdev_to_keyd(gtk_keycode_to_evdev(gtk_keycode))