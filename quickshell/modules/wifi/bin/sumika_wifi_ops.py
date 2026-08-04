#!/usr/bin/env python3
"""sumika_wifi_ops — WiFi management operations (shared library).

Pure logic for scanning, connecting, disconnecting, forgetting, diagnosing,
and auto-recovering WiFi networks via nmcli. No curses/UI dependency.

Used by:
  - sumika-wifi (thin CLI called by the Quickshell popup)
  - sumika-wifi-tui (interactive curses TUI)

All functions return plain tuples/dicts so they can be JSON-serialized by
the CLI wrapper or consumed directly by the TUI.
"""

import json
import os
import re
import subprocess
import sys
import time
from shutil import which

# ── environment / constants ──────────────────────────────────────────────

ANSI_RE = re.compile(r"\x1b\[[0-9;?]*[ -/]*[@-~]")

# Force English field values from nmcli across locales (zh_CN, ja_JP, …).
_SUBPROC_ENV = {
    **os.environ,
    "LC_ALL": "C.UTF-8",
    "LANG": "C.UTF-8",
    "LANGUAGE": "C",
}


def _state_home() -> str:
    """Sumika state dir (env-driven; matches QML Directories.sumikaStateHome)."""
    base = os.environ.get("SUMIKA_SHELL_STATE_HOME")
    if not base:
        xdg = os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state")
        base = os.path.join(xdg, "sumika-shell")
    return base


def _recovery_log_dir() -> str:
    return os.path.join(_state_home(), "wifi", "logs")


def _tee_recovery_log(on_log):
    """Wrap *on_log* so every line is also captured for a per-run log file.

    Each run writes its own file recovery-YYYYmmdd-HHMMSS.log under
    $SUMIKA_SHELL_STATE_HOME/wifi/logs/, keeping the newest 10. Returns
    (tee_fn, finalize) where finalize(ok, msg) writes the file and returns
    its path (or '' on failure)."""
    lines: list[str] = []
    started = time.strftime("%Y-%m-%d %H:%M:%S")
    stamp = time.strftime("%Y%m%d-%H%M%S")
    path = os.path.join(_recovery_log_dir(), f"recovery-{stamp}.log")

    def tee(msg):
        # Persist the same event timeline the TUI presents live. The UI adds
        # its own timestamp at render time, so callers still receive the
        # unmodified message text.
        lines.append(f"{time.strftime('%H:%M:%S')}  {msg}")
        if on_log:
            on_log(msg)

    def finalize(ok: bool, msg: str) -> str:
        try:
            os.makedirs(_recovery_log_dir(), exist_ok=True)
            body = f"=== {started}  result={'OK' if ok else 'FAIL'} ===\n"
            body += "\n".join(lines)
            body += f"\n--- {msg}\n"
            with open(path, "w", encoding="utf-8") as fh:
                fh.write(body)
            _trim_recovery_logs(keep=10)
            return path
        except OSError:
            return ""

    return tee, finalize


def _trim_recovery_logs(keep: int = 10) -> None:
    """Keep only the newest *keep* recovery-*.log files in the logs dir."""
    d = _recovery_log_dir()
    try:
        files = [f for f in os.listdir(d) if f.startswith("recovery-") and f.endswith(".log")]
    except OSError:
        return
    if len(files) <= keep:
        return
    files.sort()  # names embed YYYYmmdd-HHMMSS, so lexical == chronological
    for old in files[:-keep]:
        try:
            os.remove(os.path.join(d, old))
        except OSError:
            pass

# Cached dependency probe
_NMCLI_OK = None  # type: bool | None
_NMCLI_ERR = ""


def clean(text: str) -> str:
    return ANSI_RE.sub("", text).replace("\r", "")


# ── dependency checks ────────────────────────────────────────────────────

def require_python() -> tuple[bool, str]:
    if sys.version_info < (3, 10):
        return False, f"Python 3.10+ required (found {sys.version.split()[0]})"
    return True, ""


def ensure_nmcli() -> tuple[bool, str]:
    """Return (ok, error_message). Requires NetworkManager + nmcli."""
    global _NMCLI_OK, _NMCLI_ERR
    if _NMCLI_OK is not None:
        return _NMCLI_OK, _NMCLI_ERR
    if which("nmcli") is None:
        _NMCLI_OK = False
        _NMCLI_ERR = (
            "nmcli not found. sumika-wifi needs NetworkManager.\n"
            "  Debian/Ubuntu:  sudo apt install network-manager\n"
            "  Fedora:         sudo dnf install NetworkManager\n"
            "  Arch:           sudo pacman -S networkmanager\n"
            "Then: sudo systemctl enable --now NetworkManager"
        )
        return _NMCLI_OK, _NMCLI_ERR
    try:
        proc = subprocess.run(
            ["nmcli", "general", "status"],
            text=True, capture_output=True, timeout=5, env=_SUBPROC_ENV,
            stdin=subprocess.DEVNULL,
        )
        if proc.returncode != 0:
            err = (proc.stderr or proc.stdout or "").strip()
            _NMCLI_OK = False
            _NMCLI_ERR = (
                "NetworkManager is not reachable via nmcli.\n"
                f"{err[:200]}\n"
                "Try: sudo systemctl start NetworkManager"
            )
            return _NMCLI_OK, _NMCLI_ERR
    except (OSError, subprocess.TimeoutExpired) as e:
        _NMCLI_OK = False
        _NMCLI_ERR = f"Failed to run nmcli: {e}"
        return _NMCLI_OK, _NMCLI_ERR
    _NMCLI_OK = True
    _NMCLI_ERR = ""
    return True, ""


# ── nmcli wrapper ────────────────────────────────────────────────────────

def nmcli(*args, timeout: int = 15) -> tuple[int, str]:
    try:
        proc = subprocess.run(
            ["nmcli", *args],
            text=True, capture_output=True, timeout=timeout, env=_SUBPROC_ENV,
            stdin=subprocess.DEVNULL,
        )
        out = (proc.stdout or "") + (proc.stderr or "")
        return proc.returncode, clean(out)
    except FileNotFoundError:
        return 127, "nmcli not found"
    except subprocess.TimeoutExpired as e:
        out = ""
        if e.stdout:
            out += e.stdout if isinstance(e.stdout, str) else e.stdout.decode(errors="replace")
        if e.stderr:
            out += e.stderr if isinstance(e.stderr, str) else e.stderr.decode(errors="replace")
        return 1, clean(out)


def prepare_wifi() -> None:
    """Best-effort: unblock rfkill and power WiFi radio on."""
    try:
        subprocess.run(
            ["rfkill", "unblock", "wifi"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            stdin=subprocess.DEVNULL, timeout=3, env=_SUBPROC_ENV,
        )
        subprocess.run(
            ["rfkill", "unblock", "wlan"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            stdin=subprocess.DEVNULL, timeout=3, env=_SUBPROC_ENV,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired, OSError):
        pass
    nmcli("radio", "wifi", "on", timeout=5)


def nmcli_split(line: str) -> list[str]:
    """Split an nmcli terse (-t) line, honoring \\: and \\\\ escapes.

    Naive ``str.split(':')`` breaks on SSIDs/names that contain colons.
    """
    parts: list[str] = []
    cur: list[str] = []
    i = 0
    while i < len(line):
        ch = line[i]
        if ch == "\\" and i + 1 < len(line):
            cur.append(line[i + 1])
            i += 2
            continue
        if ch == ":":
            parts.append("".join(cur))
            cur = []
            i += 1
            continue
        cur.append(ch)
        i += 1
    parts.append("".join(cur))
    return parts


# ── radio / device / IP queries ──────────────────────────────────────────

def get_wifi_radio() -> bool:
    rc, out = nmcli("-g", "WIFI", "radio")
    val = out.strip().splitlines()[0].strip().lower() if out.strip() else ""
    if val in ("enabled", "on", "yes", "1"):
        return True
    if val in ("disabled", "off", "no", "0"):
        return False
    rc, out = nmcli("-t", "-f", "WIFI", "radio")
    return "enabled" in out.strip().lower() or out.strip().lower() == "on"


def set_wifi_radio(on: bool):
    nmcli("radio", "wifi", "on" if on else "off", timeout=5)


def get_active_connection() -> str:
    rc, out = nmcli("-t", "-f", "NAME,TYPE,DEVICE", "connection", "show", "--active")
    for line in out.splitlines():
        parts = nmcli_split(line)
        if len(parts) >= 2 and ("802-11-wireless" in parts[1] or parts[1] == "wifi"):
            return parts[0]
    return ""


def get_wifi_device() -> str:
    rc, out = nmcli("-t", "-f", "DEVICE,TYPE,STATE", "device", "status")
    fallback = ""
    for line in out.splitlines():
        parts = nmcli_split(line)
        if len(parts) < 2:
            continue
        if parts[1] != "wifi":
            continue
        if not fallback:
            fallback = parts[0]
        state = parts[2].lower() if len(parts) > 2 else ""
        if "connected" in state and "disconnected" not in state:
            return parts[0]
    return fallback


def get_ip_address(dev: str) -> str:
    if not dev:
        return "—"
    rc, out = nmcli("-g", "IP4.ADDRESS", "device", "show", dev)
    for line in out.splitlines():
        addr = line.strip()
        if not addr:
            continue
        return addr.split("/", 1)[0]
    rc, out = nmcli("-t", "-f", "IP4.ADDRESS", "device", "show", dev)
    for line in out.splitlines():
        if "IP4.ADDRESS" not in line:
            continue
        _, _, rest = line.partition(":")
        addr = rest.strip()
        if addr:
            return addr.split("/", 1)[0]
    return "—"


# ── network listing ──────────────────────────────────────────────────────

def get_saved_networks() -> list[dict]:
    rc, out = nmcli("-t", "-f", "NAME,UUID,TYPE,AUTOCONNECT,AUTOCONNECT-PRIORITY", "connection", "show")
    if rc != 0:
        return []
    active_name = get_active_connection()
    result = []
    for line in out.splitlines():
        parts = nmcli_split(line)
        if len(parts) < 3:
            continue
        name, uuid, ctype = parts[0], parts[1], parts[2]
        autoconnect_raw = parts[3] if len(parts) > 3 else "yes"
        prio_raw = parts[4] if len(parts) > 4 else "0"
        try:
            priority = int(prio_raw)
        except ValueError:
            priority = 0
        if "802-11-wireless" not in ctype and ctype != "wifi":
            continue
        ssid_rc, ssid_out = nmcli(
            "-g", "802-11-wireless.ssid", "connection", "show", "uuid", uuid,
            timeout=5,
        )
        ssid = ssid_out.strip().splitlines()[0].strip() if ssid_rc == 0 and ssid_out.strip() else name
        connected = name == active_name
        # has_credentials mirrors the popup's old `updateKnownWifiProfiles`
        # shell filter: profiles that can connect directly (open or PSK-based).
        # Enterprise (802.1X/EAP) key-mgmt is excluded — it needs nmtui.
        key_mgmt = _profile_key_mgmt(uuid).lower()
        enterprise = "eap" in key_mgmt or "802.1x" in key_mgmt or "ieee8021x" in key_mgmt
        result.append({
            "ssid": ssid,
            "name": name,
            "uuid": uuid,
            "connected": connected,
            "autoconnect": autoconnect_raw == "yes",
            "priority": priority,
            "has_credentials": not enterprise,
        })
    signal_map: dict[str, int] = {}
    security_map: dict[str, str] = {}
    rc2, out2 = nmcli("-t", "-f", "SSID,SECURITY,SIGNAL", "device", "wifi", "list", timeout=5)
    if rc2 == 0:
        for line in out2.splitlines():
            parts = nmcli_split(line)
            if len(parts) >= 1 and parts[0].strip():
                ssid = parts[0].strip()
                sec = parts[1].strip() if len(parts) > 1 else ""
                if sec and sec != "--":
                    security_map[ssid] = sec
                if len(parts) >= 3:
                    try:
                        signal_map[ssid] = int(parts[2].strip())
                    except ValueError:
                        pass
    for d in result:
        d["signal"] = signal_map.get(d["ssid"], -1)
        d["security"] = security_map.get(d["ssid"], "")
    result.sort(key=lambda d: (0 if d["connected"] else 1, d["ssid"].lower()))
    return result


def rescan_wifi(timeout: int = 10) -> tuple[bool, str]:
    """Trigger a hardware rescan. May fail if a scan is already in progress."""
    rc, out = nmcli("device", "wifi", "rescan", timeout=timeout)
    if rc == 0:
        return True, "Scan started"
    msg = out.strip() or "Rescan failed"
    if "already" in msg.lower() or "scanning" in msg.lower():
        return True, "Scan already in progress"
    return False, msg[:80]


def get_available_networks() -> list[dict]:
    """List nearby APs via nmcli terse mode. Dedup by SSID (strongest BSS).

    Fields mirror what the Quickshell popup needs: ssid/bssid/frequency for
    dedup, active (= in-use) + strength for sorting, security for the lock
    icon. This is the single source of truth — the popup no longer parses
    nmcli itself.
    """
    rc, out = nmcli(
        "-t", "-f", "SSID,BSSID,SECURITY,SIGNAL,FREQ,IN-USE,CHAN",
        "device", "wifi", "list",
        timeout=10,
    )
    if rc != 0:
        return []
    best: dict[str, dict] = {}
    for line in out.splitlines():
        if not line.strip():
            continue
        parts = nmcli_split(line)
        if len(parts) < 3:
            continue
        ssid = parts[0].strip()
        if not ssid:
            continue
        bssid = parts[1].strip() if len(parts) > 1 else ""
        sec = parts[2].strip() if len(parts) > 2 else ""
        try:
            sig = int(parts[3].strip()) if len(parts) > 3 and parts[3].strip() else 0
        except ValueError:
            sig = 0
        try:
            freq = int(parts[4].strip()) if len(parts) > 4 and parts[4].strip() else 0
        except ValueError:
            freq = 0
        in_use_field = parts[5].strip() if len(parts) > 5 else ""
        in_use = in_use_field == "*" or in_use_field.endswith("*")
        chan = parts[6].strip() if len(parts) > 6 else ""
        entry = {
            "ssid": ssid,
            "bssid": bssid,
            "security": sec if sec and sec != "--" else "",
            "signal": sig,
            "strength": sig,
            "frequency": freq,
            "active": in_use,
            "bars": "",
            "in_use": in_use,
            "chan": chan,
        }
        prev = best.get(ssid)
        if prev is None or entry["signal"] > prev["signal"] or (entry["active"] and not prev["active"]):
            best[ssid] = entry
    result = list(best.values())
    result.sort(key=lambda d: (0 if d["active"] else 1, -d["signal"], d["ssid"].lower()))
    return result


# ── security helpers ─────────────────────────────────────────────────────

def is_secured(security: str) -> bool:
    s = security.strip().lower()
    if not s or s in ("", "--", "open", "none"):
        return False
    return True


def is_enterprise(security: str) -> bool:
    s = security.upper()
    return "802.1X" in s or "EAP" in s or "ENTERPRISE" in s


def _ap_security(ssid: str) -> str:
    """Advertised security of the strongest BSS for *ssid* (scan cache).

    Returns "" when the SSID is not in the current scan results (the
    caller then skips the fix rather than blocking the connection).
    """
    rc, out = nmcli("-t", "-f", "SSID,SECURITY,SIGNAL", "device", "wifi", "list", timeout=10)
    if rc != 0:
        return ""
    best_sec, best_sig = "", -1
    for line in out.splitlines():
        parts = nmcli_split(line)
        if len(parts) < 2 or parts[0].strip() != ssid:
            continue
        sec = parts[1].strip()
        if not sec or sec == "--":
            continue
        sig = -1
        if len(parts) >= 3 and parts[2].strip():
            try:
                sig = int(parts[2].strip())
            except ValueError:
                sig = -1
        if sig > best_sig or best_sec == "":
            best_sec, best_sig = sec, sig
    return best_sec


def _profile_key_mgmt(uuid: str) -> str:
    """Current 802-11-wireless-security.key-mgmt of a saved profile."""
    rc, out = nmcli("-g", "802-11-wireless-security.key-mgmt", "connection", "show", "uuid", uuid, timeout=5)
    if rc != 0 or not out.strip():
        return ""
    return out.strip().splitlines()[0].strip()


def _profile_uuid_for_ssid(ssid: str) -> str:
    """Saved profile uuid for *ssid* ('' if none)."""
    for d in get_saved_networks():
        if d["ssid"] == ssid:
            return d["uuid"]
    return ""


def _active_wifi_ssid() -> str:
    """SSID of the active Wi-Fi profile, independent of its display name."""
    rc, out = nmcli("-t", "-f", "UUID,TYPE", "connection", "show", "--active", timeout=5)
    if rc != 0:
        return ""
    for line in out.splitlines():
        parts = nmcli_split(line)
        if len(parts) < 2 or ("802-11-wireless" not in parts[1] and parts[1] != "wifi"):
            continue
        uuid = parts[0].strip()
        if not uuid:
            continue
        ssid_rc, ssid_out = nmcli(
            "-g", "802-11-wireless.ssid", "connection", "show", "uuid", uuid, timeout=5,
        )
        if ssid_rc == 0 and ssid_out.strip():
            return ssid_out.strip().splitlines()[0].strip()
    return ""


def _wait_for_connected_route(ssid: str, dev: str, on_log=None, timeout: float = 12.0) -> tuple[bool, str]:
    """Confirm that *ssid* is active and has an IPv4 default route.

    ``nmcli device wifi connect`` can return before association/DHCP has
    completed. Treating its exit status as success was precisely what made a
    failed WPA3 association look like a successful connection in the popup.
    """
    deadline = time.monotonic() + timeout
    target_seen = False
    while time.monotonic() < deadline:
        if _active_wifi_ssid() == ssid:
            target_seen = True
            if get_ip_address(dev) != "—" and get_gateway(dev):
                return True, ""
        time.sleep(0.75)
    if target_seen:
        return False, "activation completed but no IPv4 route was assigned"
    return False, "target network did not become active"


def auto_fix_security_profile(ssid: str, uuid: str | None = None, on_log=None) -> bool:
    """Auto-fix a saved profile whose key-mgmt mismatches the AP.

    WPA2/WPA3 transition-mode APs (broadcast "WPA2 WPA3") refuse clients
    that only offer WPA-PSK: wpa_supplicant loops scanning → associating
    → disconnected and never reaches DHCP. That was the C40FA623BF09 bug
    — the AP advertised WPA3 but the profile pinned wpa-psk, so NM handed
    wpa_supplicant "WPA-PSK WPA-PSK-SHA256 FT-PSK" (no SAE) and the AP
    rejected every association until a reboot cleared the state.

    When the AP's strongest BSS advertises WPA3 and the profile still
    uses wpa-psk, flip the profile to sae so NM hands wpa_supplicant
    "SAE FT-SAE", which transition-mode APs accept. WPA2-only APs are
    left alone. Returns True if the profile was modified.
    """
    def _log(msg):
        if on_log:
            on_log(msg)

    if not ssid:
        return False
    if not uuid:
        uuid = _profile_uuid_for_ssid(ssid)
    if not uuid:
        return False  # brand-new network; NM builds the profile on connect

    sec = _ap_security(ssid)
    if not sec:
        # The list command reads NM's scan cache. A saved network may be in
        # range while that cache is cold (for example immediately after a
        # wake-up), so refresh it once before deciding that no fix is needed.
        _log("  auto-fix: refreshing Wi-Fi scan to inspect target security…")
        rescan_wifi()
        time.sleep(1.5)
        sec = _ap_security(ssid)
    if not sec or "WPA3" not in sec.upper():
        return False  # WPA2-only AP — wpa-psk is the right mode

    current = _profile_key_mgmt(uuid)
    if current in ("", "sae"):
        return False
    if current != "wpa-psk":
        return False  # don't touch enterprise / owe / wep profiles

    mod_rc, mod_out = nmcli(
        "connection", "modify", "uuid", uuid,
        "802-11-wireless-security.key-mgmt", "sae",
        timeout=10,
    )
    if mod_rc != 0:
        _log(f"  auto-fix: could not switch security mode: {_first_error_line(mod_out)}")
        return False
    _log(f"  auto-fix: AP advertises {sec} but profile used {current} — switched profile to sae")
    return True


# ── connect / disconnect / forget ────────────────────────────────────────

def _first_error_line(out: str) -> str:
    """First meaningful nmcli error line (skips 'Error:' boilerplate)."""
    for line in (out or "").splitlines():
        s = line.strip()
        if not s:
            continue
        low = s.lower()
        if low in ("error:", "error"):
            continue
        if any(k in low for k in ("error", "failed", "required", "activation")):
            return s[:100]
    return (out or "").strip()[:100] or "unknown error"


def _wait_for_ip(dev: str, tries: int = 6, delay: float = 0.4) -> str:
    """Poll for an IPv4 address after connect (DHCP may lag behind activation)."""
    if not dev or dev == "—":
        return "—"
    for _ in range(tries):
        ip = get_ip_address(dev)
        if ip and ip != "—":
            return ip
        time.sleep(delay)
    return "—"


def _connection_detail_lines(dev: str) -> list[str]:
    """Best-effort lines describing the live connection (IP/GW/signal/band)."""
    lines = []
    if not dev or dev == "—":
        return lines
    ip = _wait_for_ip(dev)
    if ip and ip != "—":
        lines.append(f"IP: {ip}")
    gw = get_gateway(dev)
    if gw:
        lines.append(f"Gateway: {gw}")
    link = get_link_info(dev)
    if link.get("signal"):
        lines.append(f"Signal: {link['signal']}")
    if link.get("band"):
        extra = f" ({link['freq']} MHz)" if link.get("freq") else ""
        lines.append(f"Band: {link['band']}{extra}")
    return lines


def connect_network(
    ssid: str,
    password: str | None = None,
    *,
    uuid: str | None = None,
    on_log=None,
) -> tuple[bool, str]:
    """Connect to a network.

    ``nmcli connection up <uuid>`` is the fast path — it reuses a saved
    profile without a scan. But it does NOT handle switching: when the
    radio is already associated with a different SSID, NM rejects it with
    "The base network connection was interrupted" (rc=4). This was the
    wedge: every recovery candidate tried ``connection up`` first, wasted
    ~10 s on the inevitable failure, then fell back to ``device wifi
    connect`` with the device in a half-activated mess.

    ``nmcli device wifi connect <ssid>`` is the GUI-click equivalent: NM
    deactivates the current connection and activates the target as one
    atomic operation — no race, no "interrupted". So:

      • switching (active ≠ ssid)  → ``device wifi connect`` directly
      • fresh connect (no active)   → ``connection up uuid`` first, then
                                       fall back to ``device wifi connect``

    If *on_log* is given, progress lines are streamed to it.
    """
    def _log(msg):
        if on_log:
            on_log(msg)

    def _confirmed_success():
        _log("Verifying association, IPv4 address, and gateway…")
        verified, detail = _wait_for_connected_route(ssid, dev, _log)
        if not verified:
            _log(f"✗ Connection was not usable: {detail}")
            return False, f"Connection failed: {detail}"
        _log(f"✓ Connected to {ssid}")
        for ln in _connection_detail_lines(dev):
            _log(f"  {ln}")
        return True, f"Connected to {ssid}"

    dev = get_wifi_device()
    if dev:
        _log(f"Using device {dev}")

    active = get_active_connection()
    switching = bool(active and active != ssid)

    try:
        # WPA2/WPA3 transition-mode APs refuse clients that only offer
        # WPA-PSK (the C40FA623BF09 bug: associating→disconnected loop,
        # never reaches DHCP). Fix the saved profile before activating so
        # the first attempt works instead of burning the fallback path.
        auto_fix_security_profile(ssid, uuid, _log)

        # ── fresh connect: try the saved profile first (fast, no scan) ──
        if not switching and uuid and not password:
            _log("Activating saved profile…")
            rc, out = nmcli("connection", "up", "uuid", uuid, timeout=30)
            if rc == 0:
                return _confirmed_success()
            _log(f"  ✗ Profile activation failed: {_first_error_line(out)}")
            _log("  Falling back to device wifi connect…")

        if not switching and uuid is None and not password:
            _log("Activating by SSID…")
            rc, out = nmcli("connection", "up", "id", ssid, timeout=30)
            if rc == 0:
                return _confirmed_success()
            _log(f"  ✗ SSID activation failed: {_first_error_line(out)}")
            _log("  Falling back to device wifi connect…")

        # ── atomic switch / fallback: device wifi connect ──
        # This is the GUI "click SSID" path. NM deactivates the current
        # connection and activates the target in one operation, so there's
        # no "base network connection was interrupted" race.
        if switching:
            _log(f"Switching from {active} (atomic)…")
        _log("Running device wifi connect…")
        args = ["device", "wifi", "connect", ssid]
        if password:
            args.extend(["password", password])
        if dev:
            args.extend(["ifname", dev])
        rc, out = nmcli(*args, timeout=45)
        if rc == 0:
            return _confirmed_success()
        err = out.strip()
        low = err.lower()
        # NM sometimes enqueues the activation when the device is busy
        # finishing a previous request; poll until it completes instead
        # of declaring failure (the activation often succeeds afterwards).
        if "enqueued" in low or "queued" in low:
            _log("  Activation queued by NM — waiting for it to complete…")
            verified, detail = _wait_for_connected_route(ssid, dev, _log, timeout=20.0)
            if verified:
                _log(f"✓ Connected to {ssid}")
                for ln in _connection_detail_lines(dev):
                    _log(f"  {ln}")
                return True, f"Connected to {ssid}"
            _log(f"  ✗ Queued activation did not complete: {detail}")
            return False, f"Connection failed (NM activation queued: {detail})"
        if "secrets were required" in low or ("password" in low and "invalid" in low):
            _log("✗ Wrong password / secrets required")
            _log(f"  nmcli: {_first_error_line(err)}")
            return False, "Wrong password / secrets required"
        if "802.1x" in low or "eap" in low:
            _log("✗ Enterprise (802.1X) networks need nmtui / nmcli")
            return False, "Enterprise (802.1X) networks need nmtui / nmcli"
        if "connection activation failed" in low or "interrupted" in low:
            _log("✗ Connection activation failed")
            _log(f"  nmcli: {_first_error_line(err)}")
            return False, "Connection failed"
        for line in err.splitlines():
            line = line.strip()
            if "Error:" in line or "error" in line.lower():
                _log(f"✗ {line[:80]}")
                return False, line[:80]
        _log(f"✗ {err[:80] if err else 'Connection failed'}")
        return False, (err[:80] if err else "Connection failed")
    finally:
        pass


def disconnect_network(dev: str) -> tuple[bool, str]:
    if not dev:
        return False, "No WiFi device"
    rc, out = nmcli("device", "disconnect", dev, timeout=10)
    if rc == 0:
        return True, "Disconnected"
    return False, out.strip()[:60] or "Disconnect failed"



def forget_network(name_or_uuid: str, *, uuid: str | None = None) -> tuple[bool, str]:
    if uuid:
        rc, out = nmcli("connection", "delete", "uuid", uuid, timeout=10)
    else:
        rc, out = nmcli("connection", "delete", "id", name_or_uuid, timeout=10)
    if rc == 0:
        return True, f"Forgot {name_or_uuid}"
    return False, out.strip()[:60] or "Delete failed"


# ── status / diagnostics ─────────────────────────────────────────────────

def get_wifi_status() -> dict:
    """Aggregate status for the popup (radio, active SSID, IP, device) plus
    the connection-type + connectivity info the popup previously parsed from
    `nmcli -t -f TYPE,STATE d status && nmcli -t -f CONNECTIVITY g` itself.
    """
    radio = get_wifi_radio()
    active_ssid = get_active_connection()
    dev = get_wifi_device()
    ip = get_ip_address(dev) if dev else "—"

    has_ethernet = False
    wifi_status = "disconnected"
    rc, out = nmcli("-t", "-f", "TYPE,STATE", "device", "status", timeout=5)
    if rc == 0:
        for line in out.splitlines():
            parts = nmcli_split(line)
            if len(parts) < 2:
                continue
            dtype, state = parts[0].strip(), parts[1].strip().lower()
            if dtype == "ethernet" and state == "connected":
                has_ethernet = True
            elif dtype == "wifi":
                if state == "connected":
                    wifi_status = "connected"
                elif state == "connecting":
                    wifi_status = "connecting"
                elif state == "disconnected":
                    if wifi_status != "connected" and wifi_status != "connecting":
                        wifi_status = "disconnected"
                elif state in ("unavailable", "unmanaged"):
                    wifi_status = "disabled"

    connectivity = "none"
    rc2, out2 = nmcli("-t", "-f", "CONNECTIVITY", "general", timeout=5)
    if rc2 == 0:
        conn = out2.strip().splitlines()
        if conn:
            connectivity = conn[0].strip().lower() or "none"

    # Limited = wifi connected but connectivity is not full.
    if wifi_status == "connected" and connectivity not in ("full",):
        wifi_status = "limited"

    # Active AP signal from the scan cache.
    strength = -1
    rc3, out3 = nmcli("-t", "-f", "IN-USE,SIGNAL", "device", "wifi", "list", timeout=5)
    if rc3 == 0:
        for line in out3.splitlines():
            if line.startswith("*"):
                parts = nmcli_split(line)
                try:
                    strength = int(parts[1].strip()) if len(parts) > 1 else -1
                except (ValueError, IndexError):
                    pass
                break

    return {
        "radio": "On" if radio else "Off",
        "active": active_ssid if active_ssid else "—",
        "ip": ip,
        "device": dev if dev else "—",
        "wifi_status": wifi_status,
        "ethernet": has_ethernet,
        "connectivity": connectivity,
        "strength": strength,
    }


def ping_stats(host: str, count: int = 5, timeout: float = 1.0) -> tuple[int, str]:
    """Ping host count times, return (loss_pct, avg_ms_str). avg_ms='fail' if lost."""
    try:
        proc = subprocess.run(
            ["ping", "-n", "-q", "-c", str(count), "-W", str(timeout), host],
            text=True, capture_output=True,
            timeout=count * timeout + 3, env=_SUBPROC_ENV,
            stdin=subprocess.DEVNULL,
        )
        out = (proc.stdout or "") + (proc.stderr or "")
    except (subprocess.TimeoutExpired, FileNotFoundError, OSError):
        return 100, "fail"
    m = re.search(r"(\d+) packets transmitted, (\d+) received, (\d+)% packet loss", out)
    loss = int(m.group(3)) if m else 100
    avg = "fail"
    m2 = re.search(r"(?:rtt|round-trip)[^=]*= ([\d.]+)/([\d.]+)/([\d.]+)", out)
    if m2:
        avg = f"{float(m2.group(2)):.1f}"
    elif loss == 0:
        ms = re.findall(r"time=([\d.]+) ms", out)
        if ms:
            avg = f"{sum(float(x) for x in ms) / len(ms):.1f}"
    return loss, avg


def get_gateway(dev: str) -> str:
    if not dev or dev == "—":
        return ""
    rc, out = nmcli("-g", "IP4.GATEWAY", "device", "show", dev, timeout=5)
    for line in out.splitlines():
        line = line.strip()
        if line and line != "--":
            return line
    return ""


def get_link_info(dev: str) -> dict:
    """Signal dBm, freq, band via iw (empty if unavailable)."""
    info = {"signal": "", "freq": "", "band": ""}
    if not dev or dev == "—" or not which("iw"):
        return info
    try:
        proc = subprocess.run(
            ["iw", "dev", dev, "link"], text=True, capture_output=True,
            timeout=3, env=_SUBPROC_ENV,
            stdin=subprocess.DEVNULL,
        )
        for line in (proc.stdout or "").splitlines():
            s = line.strip()
            if s.startswith("signal:"):
                info["signal"] = s.split("signal:")[1].strip()
            elif s.startswith("freq:"):
                f = s.split("freq:")[1].strip().split(".")[0]
                if f.isdigit():
                    fi = int(f)
                    info["freq"] = f
                    if fi >= 6000:
                        info["band"] = "6 GHz"
                    elif fi >= 5000:
                        info["band"] = "5 GHz"
                    elif fi >= 2400:
                        info["band"] = "2.4 GHz"
    except (subprocess.TimeoutExpired, FileNotFoundError, OSError):
        pass
    return info


def has_default_route(dev: str) -> bool | None:
    """Whether the kernel has an IPv4 default route through *dev*.

    ``None`` means the `ip` utility is unavailable, which is diagnostic-only
    and must not be treated as a broken network.
    """
    if not dev or dev == "—":
        return False
    try:
        proc = subprocess.run(
            ["ip", "-4", "route", "show", "default", "dev", dev],
            text=True, capture_output=True, timeout=3, env=_SUBPROC_ENV,
            stdin=subprocess.DEVNULL,
        )
    except FileNotFoundError:
        return None
    except (subprocess.TimeoutExpired, OSError):
        return False
    return proc.returncode == 0 and bool((proc.stdout or "").strip())


def dns_resolves(host: str = "one.one.one.one") -> bool | None:
    """Small DNS probe without assuming curl/dig is installed."""
    try:
        proc = subprocess.run(
            ["getent", "ahostsv4", host], text=True, capture_output=True,
            timeout=5, env=_SUBPROC_ENV, stdin=subprocess.DEVNULL,
        )
    except FileNotFoundError:
        return None
    except (subprocess.TimeoutExpired, OSError):
        return False
    return proc.returncode == 0 and bool((proc.stdout or "").strip())


def run_diagnostics() -> dict:
    """Connection health: route, DNS, gateway/external RTT, signal and band."""
    status = get_wifi_status()
    dev = status.get("device", "")
    link = get_link_info(dev)
    gw = get_gateway(dev)
    result = {
        "radio": status.get("radio", "?"),
        "active": status.get("active", "—"),
        "ip": status.get("ip", "—"),
        "device": dev,
        "gateway": gw or "—",
        "signal": link["signal"] or "—",
        "band": link["band"] or "—",
        "freq": link["freq"] or "—",
        "gateway_ms": "n/a",
        "gateway_loss": 100,
        "external_ms": "fail",
        "external_loss": 100,
        "default_route": has_default_route(dev),
        "dns": dns_resolves(),
    }
    if gw:
        loss, ms = ping_stats(gw, count=5, timeout=1)
        result["gateway_ms"] = ms
        result["gateway_loss"] = loss
    loss, ms = ping_stats("1.1.1.1", count=5, timeout=1)
    result["external_ms"] = ms
    result["external_loss"] = loss
    return result


def diag_tone(d: dict) -> str:
    """ok / warn / danger based on gateway + external reachability."""
    gw_ok = d["gateway_loss"] < 60 and d["gateway_ms"] != "fail"
    ext_ok = d["external_loss"] < 60 and d["external_ms"] != "fail"
    if gw_ok and ext_ok:
        return "ok"
    if gw_ok:
        return "warn"
    return "danger"


# ── auto-recover ─────────────────────────────────────────────────────────

def _ranked_candidates(current_ssid: str, current_failed: bool) -> list[dict]:
    """Visible autoconnect saved networks, ranked by priority*2 + signal + 5GHz bonus.
    The just-failed SSID is demoted (−30) so we try fresh networks first."""
    saved = get_saved_networks()
    available = {a["ssid"]: a for a in get_available_networks()}
    cand = []
    for s in saved:
        if not s.get("autoconnect"):
            continue
        ap = available.get(s["ssid"])
        if not ap:
            continue
        ch = ap.get("chan", "")
        try:
            chn = int(ch) if str(ch).isdigit() else 0
        except ValueError:
            chn = 0
        is_5g = chn >= 36
        prio = s.get("priority", 0)
        score = ap["signal"] + (15 if is_5g else 0) + prio * 2
        if current_ssid and s["ssid"] == current_ssid and current_failed:
            score -= 30
        cand.append({
            "ssid": s["ssid"], "uuid": s.get("uuid"), "signal": ap["signal"],
            "chan": ch, "is_5g": is_5g, "priority": prio, "score": score,
        })
    cand.sort(key=lambda c: -c["score"])
    return cand


def service_check(on_log) -> bool:
    """Step 0 of recovery: verify WiFi-related services and unblock radios.
    Returns True if everything is healthy (or was repaired), False if a hard
    block or missing device remains."""
    healthy = True

    on_log("[svc] Checking NetworkManager…")
    rc, out = nmcli("-t", "-f", "STATE", "general")
    state = out.strip().splitlines()[0].strip() if out.strip() else ""
    if rc != 0 or not state or state in ("—", "--"):
        on_log("  ✗ NetworkManager unresponsive — restarting service…")
        try:
            proc = subprocess.run(
                ["systemctl", "restart", "NetworkManager"],
                text=True, capture_output=True, timeout=20, env=_SUBPROC_ENV,
                stdin=subprocess.DEVNULL,
            )
            restart_error = clean((proc.stdout or "") + (proc.stderr or "")).strip()
        except (FileNotFoundError, subprocess.TimeoutExpired, OSError) as exc:
            proc = None
            restart_error = str(exc)
        if proc is None or proc.returncode != 0:
            detail = restart_error.splitlines()[-1][:100] if restart_error else "permission or service error"
            on_log(f"  ✗ Cannot restart NetworkManager: {detail}")
            return False
        time.sleep(3.0)
        rc2, out2 = nmcli("-t", "-f", "STATE", "general")
        if rc2 != 0 or not out2.strip():
            on_log("  ✗ NetworkManager is still unavailable after restart.")
            return False
        else:
            on_log("  ✓ NetworkManager restarted.")
    else:
        on_log(f"  ✓ NetworkManager up (state: {state}).")

    on_log("[svc] Checking WiFi device…")
    dev = get_wifi_device()
    if not dev:
        on_log("  ✗ No WiFi device found — driver may have crashed.")
        healthy = False
    else:
        on_log(f"  ✓ WiFi device {dev} present.")

    on_log("[svc] Checking rfkill (radio block)…")
    rfk_blocked = False
    rfk_hard = False
    try:
        r = subprocess.run(
            ["rfkill", "-J"],
            text=True, capture_output=True, timeout=3, env=_SUBPROC_ENV,
            stdin=subprocess.DEVNULL,
        )
        try:
            data = json.loads(r.stdout or "{}")
            for dev_rf in data.get("rfkill", []) if isinstance(data, dict) else []:
                d = dev_rf.get("type", "")
                soft = dev_rf.get("soft", False)
                hard = dev_rf.get("hard", False)
                if d in ("wlan", "wifi") and (soft or hard):
                    rfk_blocked = True
                    if hard:
                        rfk_hard = True
        except (ValueError, TypeError):
            pass
    except (FileNotFoundError, subprocess.TimeoutExpired, OSError):
        pass
    if rfk_hard:
        on_log("  ✗ WiFi HARD-blocked (hardware switch) — unblock physically.")
        healthy = False
    elif rfk_blocked:
        on_log("  ✗ WiFi soft-blocked — unblocking.")
        subprocess.run(["rfkill", "unblock", "wifi"],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                       stdin=subprocess.DEVNULL, timeout=3, env=_SUBPROC_ENV)
        subprocess.run(["rfkill", "unblock", "wlan"],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                       stdin=subprocess.DEVNULL, timeout=3, env=_SUBPROC_ENV)
        time.sleep(1.0)
        on_log("  ✓ Unblocked.")
    else:
        on_log("  ✓ rfkill clear.")

    on_log("[svc] Checking WiFi radio power…")
    if not get_wifi_radio():
        on_log("  ✗ WiFi radio off — powering on.")
        set_wifi_radio(True)
        time.sleep(1.0)
        if get_wifi_radio():
            on_log("  ✓ Radio on.")
        else:
            on_log("  ✗ Radio won't power on.")
            healthy = False
    else:
        on_log("  ✓ Radio on.")

    return healthy


def fix_connection(on_log) -> tuple[bool, str]:
    """Smart reconnect: Step 0 service health check → verify current →
    rank visible autoconnect networks → try each (connect + ping gateway);
    first that pings wins. Fallback: radio off/on reset + nmcli reload.

    Every line is persisted to its own timestamped file under
    $SUMIKA_SHELL_STATE_HOME/wifi/logs/ (newest 10 kept); the file path is
    emitted as the final log line for the user.
    `on_log(str)` is called with each progress line."""
    raw_log = on_log
    on_log, finalize = _tee_recovery_log(on_log)
    _ac_dev = ""  # device whose autoconnect we suppress for the whole recovery

    def done(ok: bool, msg: str) -> tuple[bool, str]:
        if _ac_dev:
            nmcli("device", "set", _ac_dev, "autoconnect", "yes", timeout=5)
        log_path = finalize(ok, msg)
        if log_path and raw_log:
            raw_log(f"📋 Log saved: {log_path}")
        return ok, msg
    on_log("Step 0 — Service health check")
    if not service_check(on_log):
        on_log("Recovery stopped: NetworkManager or the WiFi adapter is unavailable.")
        return done(False, "NetworkManager / WiFi adapter unavailable")
    on_log("")
    # Refresh once up front so the security audit below does not rely on a
    # stale scan cache. This also repairs a currently healthy transition-mode
    # connection permanently instead of waiting for its next failure.
    on_log("Step 1 — Scanning and auditing visible saved WiFi profiles…")
    rescan_wifi()
    time.sleep(2.0)
    audited = 0
    for profile in get_saved_networks():
        if profile.get("signal", -1) < 0:
            continue
        audited += 1
        auto_fix_security_profile(profile.get("ssid", ""), profile.get("uuid"), on_log)
    on_log(f"  ✓ Audited {audited} visible saved profile(s).")

    status = get_wifi_status()
    current = status.get("active", "") if status.get("active") not in ("", "—") else ""
    dev = status.get("device", "")

    # Suppress NM autoconnect for the ENTIRE recovery. Without this, every
    # time our device-wifi-connect gets enqueued (device busy) or a candidate
    # fails, NM's autoconnect engine grabs the radio and associates with a
    # random autoconnect=yes profile (Google-Guest-Legacy, Buffalo, etc.).
    # That hijack is why "Switching from <wrong SSID>" appears between
    # candidates and why every candidate reports "enqueued, then stalled" —
    # NM was mid-autoconnect on a different profile when we tried to switch.
    # Restored in done() on every exit path.
    if dev and dev != "—":
        _ac_dev = dev
        nmcli("device", "set", dev, "autoconnect", "no", timeout=5)
        on_log(f"NM autoconnect suppressed on {dev} for recovery.")

    current_failed = True
    if current:
        on_log(f"Checking current connection ({current})…")
        gw = get_gateway(status.get("device", ""))
        if gw:
            loss, ms = ping_stats(gw, count=3, timeout=1)
            if loss == 0 and ms != "fail":
                route_ok = has_default_route(dev)
                if route_ok is False:
                    on_log("  ✗ Gateway answers but the default route is missing.")
                elif route_ok is None:
                    on_log("  ! `ip` unavailable — cannot inspect default route.")
                else:
                    on_log("  ✓ Default route present.")
                dns_ok = dns_resolves()
                if dns_ok is False:
                    on_log("  ! DNS lookup failed — preserving WiFi link; check DNS/captive portal.")
                elif dns_ok is None:
                    on_log("  ! `getent` unavailable — cannot inspect DNS.")
                else:
                    on_log("  ✓ DNS lookup succeeded.")
                ext_loss, ext_ms = ping_stats("1.1.1.1", count=2, timeout=1)
                if ext_loss == 0 and ext_ms != "fail":
                    on_log(f"  ✓ Internet probe reachable ({ext_ms} ms).")
                else:
                    on_log("  ! Internet ICMP probe failed — preserving WiFi link (may be firewall/portal).")
                if route_ok is not False and dns_ok is not False:
                    on_log(f"  ✓ Gateway reachable ({ms} ms, 0% loss) — local network is healthy")
                    return done(True, f"Active connection verified: {current}")
                # Do not tear down a working association merely because an
                # upstream DNS/route service is unhealthy; candidate switching
                # cannot repair those conditions reliably.
                return done(False, "WiFi link is up, but DNS/default-route needs attention")
            else:
                on_log(f"  ! Gateway did not answer ICMP ({loss}% loss) — preserving active link")
            return done(True, f"Active connection preserved: {current}")
        else:
            on_log("  ✗ No gateway — current connection unusable")
            # Release the device so the candidate activations below can
            # use it. Autoconnect is already suppressed for the whole
            # recovery (see above), so NM won't re-grab this profile.
            dev0 = status.get("device", "")
            if dev0 and dev0 != "—":
                ok_d, dmsg = disconnect_network(dev0)
                on_log(f"  Disconnected {dev0} ({dmsg}).")
                for _ in range(8):
                    s = get_wifi_status()
                    if not s.get("active") or s.get("active") in ("", "—"):
                        break
                    time.sleep(0.5)
    else:
        on_log("Not connected. Starting recovery.")

    on_log("Selecting from the refreshed scan results…")

    def attempt_round(tag):
        cand = _ranked_candidates(current, current_failed)
        if not cand:
            on_log(f"[{tag}] No visible autoconnect networks found.")
            return False, ""
        on_log(f"[{tag}] {len(cand)} candidate(s): " + ", ".join(
            f"{c['ssid']}({c['signal']}%){' 5G' if c['is_5g'] else ''}" for c in cand))
        for i, c in enumerate(cand, 1):
            on_log(f"[{tag}] Trying {c['ssid']} ({c['signal']}%, prio {c['priority']})…")
            # connect_network uses device wifi connect (atomic switch) and
            # streams per-network detail into the log. Autoconnect is
            # suppressed for the whole recovery, so NM won't hijack the
            # radio between candidates.
            ok, msg = connect_network(c["ssid"], uuid=c.get("uuid"), on_log=on_log)
            if not ok:
                on_log(f"  ✗ {msg}")
                continue
            # connect_network already verified target SSID + IPv4 + gateway.
            dev = get_wifi_device()
            gw = get_gateway(dev)
            loss, ms = ping_stats(gw, count=3, timeout=1)
            if loss == 0 and ms != "fail":
                on_log(f"  ✓ Gateway OK ({ms} ms, 0% loss)")
            else:
                on_log(f"  ! Gateway ICMP unavailable ({loss}% loss); route is ready")
            return True, f"Connected to {c['ssid']}"
        return False, ""

    ok, msg = attempt_round("1")
    if ok:
        return done(True, msg)

    on_log("All candidates failed. Hard reset: radio off → on + NM reload.")
    set_wifi_radio(False)
    time.sleep(2.0)
    set_wifi_radio(True)
    time.sleep(4.0)
    nmcli("connection", "reload", timeout=10)
    prepare_wifi()
    time.sleep(2.0)
    on_log("Radio reset complete. Retrying candidates…")
    ok, msg = attempt_round("2")
    if ok:
        return done(True, msg)

    on_log("✗ Could not restore connectivity. Check router / try `t` to toggle radio.")
    return done(False, "Recovery failed — check router or toggle WiFi")
