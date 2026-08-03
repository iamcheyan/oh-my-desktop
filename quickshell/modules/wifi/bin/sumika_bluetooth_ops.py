#!/usr/bin/env python3
"""sumika_bluetooth_ops — Bluetooth management operations (shared library).

Pure logic for scanning, pairing, connecting, disconnecting, trusting,
removing, and powering Bluetooth devices via bluetoothctl. No curses/UI.

Used by:
  - sumika-bluetooth (thin CLI called by the Quickshell BluetoothStatus service)
  - sumika-bluetooth-tui (interactive curses TUI)

Pairing uses an interactive PTY bluetoothctl session (needed for agent
passkey/PIN prompts). All other ops are one-shot subprocess calls.
"""

import os
import random
import re
import select
import subprocess
import sys
import time
from shutil import which

# ── environment / constants ──────────────────────────────────────────────

_SUBPROC_ENV = {
    **os.environ,
    "LC_ALL": "C.UTF-8",
    "LANG": "C.UTF-8",
    "LANGUAGE": "C",
}

ANSI_RE = re.compile(r"\x1b\[[0-9;?]*[ -/]*[@-~]")
ADDR_RE = re.compile(r"([0-9A-Fa-f]{2}[:]){5}[0-9A-Fa-f]{2}")
DEVICE_RE = re.compile(r"\[(?:NEW|CHG)\]\s+Device\s+([0-9A-Fa-f:]{17})\s+(.*)")
NEW_DEVICE_RE = re.compile(r"\[NEW\]\s+Device\s+([0-9A-Fa-f:]{17})\s+(.*)")
PIN_RE = re.compile(r"\[agent\]\s*PIN code:\s*([0-9]{4,6})", re.IGNORECASE)
PASSKEY_RE = re.compile(r"\[agent\]\s*Passkey:\s*([0-9]{4,6})", re.IGNORECASE)
CONFIRM_RE = re.compile(r"Confirm passkey[^0-9]*([0-9]{4,6})", re.IGNORECASE)
PAIRED_RE = re.compile(r"Pairing successful|Paired:\s*yes", re.IGNORECASE)
CONNECTED_RE = re.compile(r"Connection successful", re.IGNORECASE)
CONNECTED_CHG_RE = re.compile(r"Connected:\s*yes", re.IGNORECASE)


def clean(text: str) -> str:
    return ANSI_RE.sub("", text).replace("\r", "")


# ── icon / type maps (UI helpers, but shared so the CLI can use them too) ──

ICON_MAP = {
    "input-keyboard":      "\uf11c",
    "input-mouse":         "\uefba",
    "input-tablet":        "\uf10a",
    "input-gaming":        "\uf11b",
    "audio-headset":       "\uf025",
    "audio-card":          "\uf025",
    "audio-speaker":       "\uf028",
    "audio-input-microphone": "\uf130",
    "video-display":       "\uf108",
    "video-camera":        "\uf030",
    "camera":              "\uf030",
    "computer":            "\uf108",
    "phone":               "\uf10b",
    "printer":             "\uf02f",
    "scanner":             "\uf030",
    "network-wireless":    "\uf1eb",
    "multimedia-player":   "\uf025",
    "wearable":            "\uf2f1",
}
ICON_UNKNOWN = "\uf059"

NAME_GUESS_MAP = {
    "keyboard": "input-keyboard", "mouse": "input-mouse",
    "headphone": "audio-headset", "headset": "audio-headset",
    "earbud": "audio-headset", "airpods": "audio-headset",
    "soundlink": "audio-speaker", "speaker": "audio-speaker",
    "loudspeaker": "audio-speaker", "soundcore": "audio-speaker",
    "controller": "input-gaming", "gamepad": "input-gaming",
    "watch": "wearable", "smartwatch": "wearable",
    "desktop": "computer", "laptop": "computer",
    "printer": "printer", "scanner": "scanner", "camera": "camera",
    "tablet": "input-tablet", "iphone": "phone", "galaxy": "phone",
    "pixel": "phone", "fitbit": "wearable", "band": "wearable",
    "dual": "input-gaming", "xbox": "input-gaming", "playstation": "input-gaming",
}

TYPE_LABELS = {
    "input-keyboard": "Keyboard", "input-mouse": "Mouse",
    "input-tablet": "Tablet", "input-gaming": "Gamepad",
    "audio-headset": "Headset", "audio-card": "Audio",
    "audio-speaker": "Speaker", "audio-input-microphone": "Microphone",
    "video-display": "Display", "video-camera": "Camera",
    "camera": "Camera", "computer": "Computer", "phone": "Phone",
    "printer": "Printer", "scanner": "Scanner",
    "network-wireless": "Network", "multimedia-player": "Media Player",
    "wearable": "Wearable",
}


def _icon_from_appearance(appearance: int) -> str | None:
    table = {
        0x0040: "input-keyboard", 0x0080: "input-mouse",
        0x0180: "wearable", 0x0180 + 0x40: "wearable",
        0x0400: "audio-headset", 0x0400 + 0x10: "audio-speaker",
        0x0500: "audio-speaker",
    }
    return table.get(appearance)


def _icon_from_class(cod: int) -> str | None:
    major = (cod >> 8) & 0x1F
    minor = (cod >> 2) & 0x3F
    if major == 0x05:
        return "phone"
    if major == 0x04:
        return "audio-headset" if minor & 0x40 else "audio-speaker"
    if major == 0x03:
        return "network-wireless"
    if major == 0x06:
        return "input-mouse" if cod & 0x80 else "input-keyboard"
    if major == 0x01:
        return "computer"
    if major == 0x07:
        return "wearable"
    return None


def device_icon(info_text: str, name: str = "") -> str:
    m = re.search(r"^\s*Icon:\s*(\S+)", info_text, re.MULTILINE)
    if m and m.group(1) in ICON_MAP:
        return ICON_MAP[m.group(1)]
    m = re.search(r"^\s*Appearance:\s*(?:0x)?([0-9a-fA-F]+)", info_text, re.MULTILINE)
    if m:
        key = _icon_from_appearance(int(m.group(1), 16))
        if key and key in ICON_MAP:
            return ICON_MAP[key]
    m = re.search(r"^\s*Class:\s*(?:0x)?([0-9a-fA-F]+)", info_text, re.MULTILINE)
    if m:
        key = _icon_from_class(int(m.group(1), 16))
        if key and key in ICON_MAP:
            return ICON_MAP[key]
    if name:
        n = name.lower()
        for keyword, icon_key in NAME_GUESS_MAP.items():
            if keyword in n:
                return ICON_MAP.get(icon_key, ICON_UNKNOWN)
    return ICON_UNKNOWN


def device_type_label(info_text: str, name: str = "") -> str:
    m = re.search(r"^\s*Appearance:\s*(?:0x)?([0-9a-fA-F]+)", info_text, re.MULTILINE)
    if m:
        key = _icon_from_appearance(int(m.group(1), 16))
        if key:
            return TYPE_LABELS.get(key, "")
    m = re.search(r"^\s*Class:\s*(?:0x)?([0-9a-fA-F]+)", info_text, re.MULTILINE)
    if m:
        key = _icon_from_class(int(m.group(1), 16))
        if key:
            return TYPE_LABELS.get(key, "")
    m = re.search(r"^\s*Icon:\s*(\S+)", info_text, re.MULTILINE)
    if m:
        return TYPE_LABELS.get(m.group(1), "")
    if name:
        n = name.lower()
        for keyword, icon_key in NAME_GUESS_MAP.items():
            if keyword in n:
                return TYPE_LABELS.get(icon_key, "")
    return ""


# ── PTY helpers (interactive bluetoothctl sessions for scan/pair) ────────

def pty_spawn(argv):
    pid, fd = os.forkpty()
    if pid == 0:
        try:
            os.environ.update({
                "LC_ALL": "C.UTF-8",
                "LANG": "C.UTF-8",
                "LANGUAGE": "C",
            })
            os.execvp(argv[0], argv)
        except Exception as exc:
            print(exc, file=sys.stderr)
            os._exit(127)
    return pid, fd


def send(fd, command: str):
    try:
        os.write(fd, (command + "\n").encode())
    except OSError:
        pass


# ── dependency checks ────────────────────────────────────────────────────

def require_python() -> tuple[bool, str]:
    if sys.version_info < (3, 10):
        return False, f"Python 3.10+ required (found {sys.version.split()[0]})"
    return True, ""


def ensure_bluetoothctl() -> tuple[bool, str]:
    if which("bluetoothctl") is None:
        return False, (
            "bluetoothctl not found. sumika-bluetooth needs BlueZ.\n"
            "  Debian/Ubuntu:  sudo apt install bluez\n"
            "  Fedora:         sudo dnf install bluez\n"
            "  Arch:           sudo pacman -S bluez bluez-utils\n"
            "Then: sudo systemctl enable --now bluetooth"
        )
    try:
        proc = subprocess.run(
            ["bluetoothctl", "show"],
            text=True, capture_output=True, timeout=5, env=_SUBPROC_ENV,
        )
        out = (proc.stdout or "") + (proc.stderr or "")
        if "No default controller" in out or "No controller" in out:
            return False, (
                "No Bluetooth controller found.\n"
                "Check the adapter is present and: sudo systemctl start bluetooth"
            )
        if proc.returncode != 0 and "Controller" not in out:
            return False, f"bluetoothctl failed:\n{out.strip()[:200]}"
    except (OSError, subprocess.TimeoutExpired) as e:
        return False, f"Failed to run bluetoothctl: {e}"
    return True, ""


# ── one-shot bluetoothctl wrapper ────────────────────────────────────────

def btctl_simple(*args, timeout: int = 10) -> tuple[int, str]:
    cmd = ["bluetoothctl", *args]
    try:
        proc = subprocess.run(
            cmd, text=True, capture_output=True, timeout=timeout, env=_SUBPROC_ENV,
        )
        out = (proc.stdout or "") + (proc.stderr or "")
        return proc.returncode, out
    except FileNotFoundError:
        return 127, "bluetoothctl not found"
    except subprocess.TimeoutExpired as e:
        out = ""
        if e.stdout:
            out += e.stdout if isinstance(e.stdout, str) else e.stdout.decode(errors="replace")
        if e.stderr:
            out += e.stderr if isinstance(e.stderr, str) else e.stderr.decode(errors="replace")
        return 1, out


def prepare_bluetooth() -> None:
    """Best-effort: unblock rfkill, power on, pairable on."""
    try:
        subprocess.run(
            ["rfkill", "unblock", "bluetooth"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            timeout=3, env=_SUBPROC_ENV,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired, OSError):
        pass
    btctl_simple("power", "on", timeout=5)
    btctl_simple("pairable", "on", timeout=5)


# ── device/adapter queries ───────────────────────────────────────────────

def parse_battery_pct(info: str) -> int | None:
    m = re.search(r"Battery Percentage:\s*(?:0x[0-9a-fA-F]+\s*)?\((\d+)\)", info)
    if m:
        return int(m.group(1))
    return None


def format_battery(pct: int | None) -> str:
    if pct is None:
        return ""
    if pct >= 90:
        icon = "\U000f0948"
    elif pct >= 80:
        icon = "\U000f0945"
    elif pct >= 70:
        icon = "\U000f0944"
    elif pct >= 60:
        icon = "\U000f0943"
    elif pct >= 50:
        icon = "\U000f0942"
    elif pct >= 40:
        icon = "\U000f0941"
    elif pct >= 30:
        icon = "\U000f0940"
    elif pct >= 20:
        icon = "\U000f093f"
    else:
        icon = "\U000f093e"
    return f"{pct}% {icon}"


def get_hci_name() -> str:
    try:
        names = sorted(
            n for n in os.listdir("/sys/class/bluetooth")
            if n.startswith("hci") and ":" not in n
        )
        if names:
            return names[0]
    except OSError:
        pass
    return "hci0"


def yesno_bool(val: str) -> bool:
    return val.strip().lower() in ("yes", "true", "on", "1")


def get_devices_info() -> list[dict]:
    _, out = btctl_simple("devices")
    _, paired_out = btctl_simple("devices", "Paired")
    lines = list(out.splitlines()) + list(paired_out.splitlines())
    seen_addrs: set[str] = set()
    result = []
    for line in lines:
        m = re.match(r"Device\s+([0-9A-Fa-f:]{17})\s+(.*)", line)
        if not m:
            continue
        addr, name = m.group(1), m.group(2).strip()
        key = addr.upper()
        if key in seen_addrs:
            continue
        seen_addrs.add(key)
        try:
            _, info = btctl_simple("info", addr, timeout=3)
        except Exception:
            info = ""
        if not info:
            info = ""
        icon = device_icon(info, name)
        paired = bool(re.search(r"Paired:\s*yes", info, re.I))
        connected = bool(re.search(r"Connected:\s*yes", info, re.I))
        trusted = bool(re.search(r"Trusted:\s*yes", info, re.I))
        blocked_raw = re.search(r"Blocked:\s*(yes|no)", info, re.I)
        blocked = blocked_raw.group(1) if blocked_raw else ""
        rssi_m = re.search(r"RSSI:\s*(-?\d+)", info, re.I)
        rssi = f"{rssi_m.group(1)} dBm" if rssi_m else ""
        adapter_m = re.search(r"Adapter:.*?hci(\d+)", info, re.I)
        adapter = f"hci{adapter_m.group(1)}" if adapter_m else ""
        type_label = device_type_label(info, name)
        battery_pct = parse_battery_pct(info)
        if connected:
            status = "connected"
        elif paired:
            status = "paired"
        else:
            status = "available"
        result.append({
            "addr": addr,
            "name": name or addr,
            "status": status,
            "icon": icon,
            "trusted": trusted,
            "blocked": blocked,
            "rssi": rssi,
            "adapter": adapter,
            "type_label": type_label,
            "battery": format_battery(battery_pct),
            "battery_pct": battery_pct,
            "favorite": False,
        })
    order = {"connected": 0, "paired": 1, "available": 2}
    result.sort(key=lambda d: order.get(d["status"], 3))
    return result


def get_adapter_info() -> dict | None:
    _, out = btctl_simple("show")
    m = re.search(r"Controller\s+([0-9A-Fa-f:]+)", out)
    if not m:
        return None

    def g(key: str) -> str:
        mm = re.search(rf"^\s*{key}:\s*(.+)", out, re.MULTILINE)
        return mm.group(1).strip() if mm else "?"

    powered = yesno_bool(g("Powered"))
    pairable = yesno_bool(g("Pairable"))
    discoverable = yesno_bool(g("Discoverable"))
    return {
        "name": get_hci_name(),
        "alias": g("Alias"),
        "powered": "On" if powered else "Off",
        "pairable": "true" if pairable else "false",
        "discoverable": "true" if discoverable else "false",
    }


# ── operations: connect / disconnect / trust / remove ────────────────────

def connect_device(addr: str, *, retries: int = 3, timeout: int = 25) -> tuple[bool, str]:
    """Connect to a paired device, with trust + retry (asahi wake-flags workaround)."""
    btctl_simple("trust", addr)
    for attempt in range(1, retries + 1):
        code, out = btctl_simple("--timeout", str(timeout), "connect", addr, timeout=timeout + 5)
        if code == 0 and re.search(r"successful|Connection successful", out, re.IGNORECASE):
            return True, f"Connected to {addr}"
        # Check if actually connected despite error exit
        _, info = btctl_simple("info", addr, timeout=3)
        if re.search(r"Connected:\s*yes", info, re.I):
            return True, f"Connected to {addr}"
        if attempt < retries:
            time.sleep(2)
    return False, out.strip()[:80] or "Connection failed"


def disconnect_device(addr: str) -> tuple[bool, str]:
    code, out = btctl_simple("disconnect", addr, timeout=15)
    if code == 0:
        return True, f"Disconnected from {addr}"
    return False, out.strip()[:80] or "Disconnect failed"


def trust_device(addr: str) -> tuple[bool, str]:
    code, out = btctl_simple("trust", addr, timeout=10)
    if code == 0:
        return True, f"Trusted {addr}"
    return False, out.strip()[:80] or "Trust failed"


def untrust_device(addr: str) -> tuple[bool, str]:
    code, out = btctl_simple("untrust", addr, timeout=10)
    if code == 0:
        return True, f"Untrusted {addr}"
    return False, out.strip()[:80] or "Untrust failed"


def remove_device(addr: str) -> tuple[bool, str]:
    code, out = btctl_simple("remove", addr, timeout=15)
    if code == 0:
        return True, f"Removed {addr}"
    return False, out.strip()[:80] or "Remove failed"


def power_on() -> tuple[bool, str]:
    prepare_bluetooth()
    return True, "Bluetooth powered on"


def power_off() -> tuple[bool, str]:
    code, out = btctl_simple("power", "off", timeout=5)
    if code == 0:
        return True, "Bluetooth powered off"
    return False, out.strip()[:80] or "Power off failed"


def is_trusted(addr: str) -> bool:
    _, info = btctl_simple("info", addr, timeout=3)
    return bool(re.search(r"Trusted:\s*yes", info, re.I))


def is_paired(addr: str) -> bool:
    _, info = btctl_simple("info", addr, timeout=3)
    return bool(re.search(r"Paired:\s*yes", info, re.I))


def is_connected(addr: str) -> bool:
    _, info = btctl_simple("info", addr, timeout=3)
    return bool(re.search(r"Connected:\s*yes", info, re.I))


# ── pairing (interactive PTY session) ────────────────────────────────────

def parse_passkey(text: str) -> str:
    patterns = [
        r"\[agent\]\s*PIN code:\s*([0-9]{4,6})",
        r"\[agent\]\s*Passkey:\s*([0-9]{4,6})",
        r"Confirm passkey[^0-9]*([0-9]{4,6})",
        r"passkey[^0-9]*([0-9]{6})",
    ]
    for pattern in patterns:
        match = re.search(pattern, text, re.IGNORECASE)
        if match:
            return match.group(1).zfill(6)
    return ""


def pair_device(addr: str, *, on_status=None, on_log=None, on_passkey=None,
                timeout: int = 90) -> tuple[bool, str]:
    """Pair with a device using an interactive bluetoothctl session.

    Callbacks (all optional, called in real-time):
      on_status(str)  — status updates: "pairing", "found", "paired", etc.
      on_log(str)     — raw bluetoothctl output lines
      on_passkey(str) — passkey/PIN to show the user

    Handles both SSP (passkey confirm) and legacy pairing (PIN entry).
    Auto-confirms passkeys; generates a random PIN for legacy devices.
    After successful pairing, trusts + connects the device.
    """
    def status(msg):
        if on_status:
            on_status(msg)
    def log(msg):
        if on_log:
            on_log(msg)
    def passkey(msg):
        if on_passkey:
            on_passkey(msg)

    target_token = addr.upper()
    status("pairing")
    passkey("")
    log("Starting interactive pairing session…")

    pid, fd = pty_spawn(["bluetoothctl", "--agent", "KeyboardDisplay"])
    started = time.monotonic()
    recent = ""
    line_buffer = ""
    sent_pair = False
    sent_pin = False
    last_passkey = ""
    paired = False
    error = ""
    target_seen = False

    try:
        send(fd, "power on")
        send(fd, "pairable on")
        send(fd, "agent KeyboardDisplay")
        send(fd, "default-agent")
        send(fd, f"remove {addr}")
        send(fd, "scan on")

        while time.monotonic() - started < timeout:
            if not sent_pair and target_seen:
                send(fd, "scan off")
                send(fd, f"pair {addr}")
                sent_pair = True

            readable, _, _ = select.select([fd], [], [], 0.2)
            if not readable:
                continue

            try:
                chunk = os.read(fd, 4096).decode(errors="replace")
            except OSError:
                break

            if not chunk:
                continue

            clean_chunk = clean(chunk)
            recent = (recent + clean_chunk)[-4000:]
            line_buffer += clean_chunk
            target_event = re.search(
                r"\[(NEW|CHG)\]\s+DEVICE\s+" + re.escape(target_token),
                clean_chunk.upper(),
            )
            if target_event:
                target_seen = True
                status("found")
            while "\n" in line_buffer:
                line, line_buffer = line_buffer.split("\n", 1)
                if line.strip():
                    log(line)

            pk = parse_passkey(recent)
            if pk and pk != last_passkey:
                last_passkey = pk
                passkey(pk)

            lower = recent.lower()
            if ("confirm passkey" in lower or "(yes/no)" in lower or "yes/no" in lower) and "agent" in lower:
                send(fd, "yes")

            if ("enter pin code" in lower or "request pin code" in lower) and not sent_pin:
                pin = str(random.randint(0, 999999)).zfill(6)
                sent_pin = True
                last_passkey = pin
                passkey(pin)
                send(fd, pin)

            if "pairing successful" in lower or "paired: yes" in lower:
                paired = True
                status("paired")
                break

            fail_match = re.search(r"Failed to pair:[^\r\n]*", recent)
            if fail_match:
                error = fail_match.group(0)
                break

            if "authenticationfailed" in lower or "authenticationtimeout" in lower or "authenticationcanceled" in lower:
                error = "Bluetooth authentication failed or timed out."
                break
    finally:
        try:
            send(fd, "quit")
        except OSError:
            pass
        try:
            os.close(fd)
        except OSError:
            pass
        try:
            os.waitpid(pid, 0)
        except ChildProcessError:
            pass

    if not paired and is_paired(addr):
        paired = True
        status("paired")

    if not paired:
        if not target_seen:
            return False, "Device was not rediscovered. Put it in Bluetooth pairing mode and try again."
        return False, error or "Pairing timed out. Put the device in pairing mode and try again."

    # Trust + connect after successful pairing
    status("trusting")
    trust_device(addr)
    status("connecting")
    ok, msg = connect_device(addr)
    if ok:
        status("connected")
        return True, f"Paired and connected to {addr}"
    return True, f"Paired with {addr} but connection failed: {msg}"