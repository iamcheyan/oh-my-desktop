"""Shared formatting/parsing helpers for Sumika key capture output."""

from __future__ import annotations

import re
from typing import Any


def build_clipboard_text(
    raw: str,
    keyval: int | None = None,
    keycode: int | None = None,
    keyname: str | None = "",
    keyd_name: str | None = "",
    evdev_code: int | None = None,
) -> str:
    """Return a stable, human-readable clipboard payload for key-test."""
    lines = [
        "# Sumika key capture",
        f"bind: {raw or ''}",
    ]
    if keyd_name:
        lines.append(f"keyd: {keyd_name}")
    if keyname:
        lines.append(f"keyname: {keyname}")
    if keyval is not None:
        lines.append(f"keyval: {keyval}")
    if keycode is not None:
        lines.append(f"keycode: {keycode}")
    if evdev_code is not None:
        lines.append(f"evdev: {evdev_code}")
    return "\n".join(lines) + "\n"


def parse_clipboard_text(text: str) -> dict[str, Any]:
    """Parse key-test clipboard payloads, including older loose formats."""
    result: dict[str, Any] = {}
    for raw_line in (text or "").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or line.startswith("✓") or line.startswith("✗"):
            continue
        key, sep, value = line.partition(":")
        if sep:
            key = key.strip().lower()
            value = value.strip()
            if key in {"bind", "hypr", "raw"}:
                result["bind"] = value
            elif key in {"keyd", "keyd-name"}:
                result["keyd"] = value
            elif key == "keyname":
                result["keyname"] = value
            elif key in {"keyval", "keycode", "evdev"}:
                result[key] = _parse_int(value)
            continue
        if "bind" not in result:
            result["bind"] = line

    if "bind" not in result:
        match = re.search(r"Hypr/GDK:\s*([^\n/]+)", text or "")
        if match:
            result["bind"] = match.group(1).strip()
    return result


def _parse_int(value: str) -> int | None:
    try:
        return int(str(value).strip(), 0)
    except Exception:
        return None
