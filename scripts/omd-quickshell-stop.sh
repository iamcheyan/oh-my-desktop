#!/bin/sh
# Stop OMD Quickshell processes — only the quickshell binaries themselves.
#
# We do NOT use `systemctl stop` because that destroys the unit's cgroup,
# killing user apps (terminals, Firefox, etc.) that were launched from the
# bar and inherited its cgroup. Instead, pkill targets only quickshell
# processes by their command line, leaving cgroup siblings untouched.

omd_stop_quickshell() {
    omd_root="${OMD_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
    runtime_dir="/run/user/$(id -u)"

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

    # ── Reset unit state so omd-restart can create fresh units ───────────
    # The units are now inactive (main process died). Clean up transient
    # definitions without touching cgroups (processes already gone).
    apps="omd-bar omd-polkit"
    if command -v jq >/dev/null 2>&1 && [ -f "$_registry_file" ]; then
        while IFS=" " read -r instance module_id; do
            [ -z "$instance" ] && continue
            apps="$apps $instance"
        done <<EOF
$(jq -r '
  .modules[] |
  select(.kind == "application" and (.entry | length > 0)) |
  "\(.entry.instance // .id) \(.id)"
' "$_registry_file" 2>/dev/null || true)
EOF
    fi
    for app in $apps; do
        systemctl --user reset-failed "$app.service" >/dev/null 2>&1 || true
        rm -f "$runtime_dir/systemd/transient/$app.service" 2>/dev/null || true
    done
    systemctl --user daemon-reload >/dev/null 2>&1 || true
}