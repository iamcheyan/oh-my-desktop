"""Map captured key strings (from key-test / Hyprland) to keyd key names."""

HYPR_TO_KEYD = {
    "CAPS_LOCK": "capslock",
    "CAPSLOCK": "capslock",
    "ESCAPE": "escape",
    "TAB": "tab",
    "SPACE": "space",
    "RETURN": "enter",
    "ENTER": "enter",
    "KP_ENTER": "enter",
    "BACKSPACE": "backspace",
    "DELETE": "delete",
    "INSERT": "insert",
    "HOME": "home",
    "END": "end",
    "PAGE_UP": "pageup",
    "PAGE_DOWN": "pagedown",
    "LEFT": "left",
    "RIGHT": "right",
    "UP": "up",
    "DOWN": "down",
    "CONTROL_L": "leftcontrol",
    "CONTROL_R": "rightcontrol",
    "LCONTROL": "leftcontrol",
    "RCONTROL": "rightcontrol",
    "LEFTCTRL": "leftcontrol",
    "RIGHTCTRL": "rightcontrol",
    "ALT_L": "leftalt",
    "ALT_R": "rightalt",
    "LEFTALT": "leftalt",
    "RIGHTALT": "rightalt",
    "SUPER_L": "leftmeta",
    "SUPER_R": "rightmeta",
    "META_L": "leftmeta",
    "META_R": "rightmeta",
    "LEFTMETA": "leftmeta",
    "RIGHTMETA": "rightmeta",
    "SHIFT_L": "leftshift",
    "SHIFT_R": "rightshift",
    "LEFTSHIFT": "leftshift",
    "RIGHTSHIFT": "rightshift",
    "PRINT": "printscreen",
    "SYSRQ": "printscreen",
    "SCROLL_LOCK": "scrolllock",
    "NUM_LOCK": "numlock",
    "PAUSE": "pause",
    "MUHENKAN": "muhenkan",
    "HENKAN": "henkan",
    "KATAKANA": "katakana",
    "KATAKANAHIRAGANA": "katakanahiragana",
    "ZENKAKUHANKAKU": "zenkakuhankaku",
    "ZENKAKU_HANKAKU": "zenkakuhankaku",
    "ZENKAKU": "zenkakuhankaku",
    "ESC": "esc",
    "ESCAPE": "esc",
    "GRAVE": "grave",
    "BACKQUOTE": "grave",
    "QUOTELEFT": "grave",
}


def hypr_to_keyd(raw: str) -> str | None:
    if not raw:
        return None
    raw = raw.strip()
    if not raw or raw.startswith("✓") or raw.startswith("✗") or len(raw) > 64:
        return None
    if " + " in raw:
        return None
    if raw.lower().startswith("code:"):
        return None

    key = raw.upper().replace("-", "_")
    if key in HYPR_TO_KEYD:
        return HYPR_TO_KEYD[key]

    norm = key.replace("_", "")
    if norm in HYPR_TO_KEYD:
        return HYPR_TO_KEYD[norm]
    if len(norm) == 1 and norm.isalpha():
        return norm.lower()
    if norm.startswith("F") and norm[1:].isdigit() and 1 <= int(norm[1:]) <= 24:
        return norm.lower()
    return None