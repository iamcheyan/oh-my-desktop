"""Shared clipboard format for OMD key-test captures."""

from key_evdev_names import gtk_keycode_to_evdev, gtk_keycode_to_keyd


def build_clipboard_text(
    bind: str,
    keyval: int,
    keycode: int,
    keyname: str = "",
    keyd_name: str = "",
    evdev_code: int | None = None,
) -> str:
    if not keyd_name:
        keyd_name = gtk_keycode_to_keyd(keycode) or ""
    if evdev_code is None:
        evdev_code = gtk_keycode_to_evdev(keycode)

    lines = []
    if keyd_name:
        lines.append(f"keyd-name:{keyd_name}")
    if evdev_code is not None:
        lines.append(f"evdev-code:{evdev_code}")
    lines.append(bind)
    lines.append(f"gdk-keyval:{keyval}")
    if keyname:
        lines.append(f"gdk-keyname:{keyname}")
    lines.append(f"hardware-code:{keycode}")
    return "\n".join(lines)


def parse_clipboard_text(text: str) -> dict:
    bind = ""
    keyval = None
    keyname = ""
    keycode = None
    keyd_name = ""
    evdev_code = None

    for line in (text or "").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("keyd-name:"):
            keyd_name = line.split(":", 1)[1].strip()
            continue
        if line.startswith("evdev-code:"):
            try:
                evdev_code = int(line.split(":", 1)[1].strip())
            except ValueError:
                pass
            continue
        if line.startswith("gdk-keyval:"):
            try:
                keyval = int(line.split(":", 1)[1].strip())
            except ValueError:
                pass
            continue
        if line.startswith("gdk-keyname:"):
            keyname = line.split(":", 1)[1].strip()
            continue
        if line.startswith("hardware-code:"):
            try:
                keycode = int(line.split(":", 1)[1].strip())
            except ValueError:
                pass
            continue
        if not bind:
            bind = line

    if not keyd_name and keycode is not None:
        keyd_name = gtk_keycode_to_keyd(keycode) or ""
    if evdev_code is None and keycode is not None:
        evdev_code = gtk_keycode_to_evdev(keycode)

    return {
        "bind": bind,
        "keyval": keyval,
        "keyname": keyname,
        "keycode": keycode,
        "keyd": keyd_name,
        "evdev": evdev_code,
    }