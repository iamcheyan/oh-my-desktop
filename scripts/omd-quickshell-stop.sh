#!/bin/sh
# Stop OMD Quickshell processes — only the quickshell binaries themselves.
#
# We use pkill (not `systemctl stop`) because systemd destroys the unit
# cgroup when the main process dies, which would kill user apps (terminals,
# Firefox, etc.) that inherited the bar's cgroup. pkill targets only
# quickshell processes by command line, leaving everything else untouched.
#
# We also don't use systemd-run to start processes (see omd-restart) —
# setsid processes have no unit cgroup, so pkill is completely safe.

omd_stop_quickshell() {
    omd_root="${OMD_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

    # ── Kill only quickshell processes ───────────────────────────────────
    # Match by config path so we never hit unrelated quickshell instances.
    # SIGTERM first, then SIGKILL for stragglers after a brief grace period.
    pkill -f "/usr/bin/quickshell -p ${omd_root}/" 2>/dev/null || true
    sleep 0.3
    pkill -9 -f "/usr/bin/quickshell -p ${omd_root}/" 2>/dev/null || true
    sleep 0.15

    # ── Watcher cleanup (nmcli, cliphist, etc.) ─────────────────────────
    _registry_file="${SUMIKA_MODULE_REGISTRY:-${SUMIKA_SHELL_RUNTIME_DIR:-/run/user/$(id -u)/sumika-shell}/modules.json}"
    if command -v jq >/dev/null 2>&1 && [ -f "$_registry_file" ]; then
        while IFS="" read -r watcher; do
            [ -z "$watcher" ] && continue
            pkill -f "$watcher" 2>/dev/null || true
        done <<WATCHERS
$(jq -r '
  .modules[] |
  select(.contributes.watchers? // [] | length > 0) |
  .contributes.watchers[]
' "$_registry_file" 2>/dev/null || true)
WATCHERS
    else
        pkill -f "(^|/)nmcli monitor$" 2>/dev/null || true
    fi

    # Clipboard daemon has its own stop subcommand
    _clipboard_module=""
    if command -v jq >/dev/null 2>&1 && [ -f "$_registry_file" ]; then
        _clipboard_module=$(jq -r '.modules[] | select(.id == "clipboard") | .path // empty' "$_registry_file" 2>/dev/null || true)
    fi
    if [ -n "$_clipboard_module" ] && [ -x "$_clipboard_module/bin/omd-clipboard-store" ]; then
        "$_clipboard_module/bin/omd-clipboard-store" stop >/dev/null 2>&1 || true
    fi

    # ── Clean up stale systemd units from previous runs ─────────────────
    # Best-effort: if any omd-* units exist from older versions that used
    # systemd-run, stop and remove them. Harmless if no units exist.
    for unit in omd-bar omd-polkit omd-overview omd-applauncher; do
        systemctl --user stop "$unit.service" 2>/dev/null || true
        systemctl --user reset-failed "$unit.service" 2>/dev/null || true
    done
    rm -f "/run/user/$(id -u)/systemd/transient/omd-"*.service 2>/dev/null || true
}