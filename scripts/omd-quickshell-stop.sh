#!/bin/sh
# Stop OMD Quickshell processes.
#
# Foot terminals, tmux, and other apps launched from omd-applauncher inherit its
# systemd cgroup. `systemctl stop` tears down the whole cgroup, so we only signal
# the unit main process and rely on targeted pkill for the quickshell binary.

omd_stop_quickshell() {
    omd_root="${OMD_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
    runtime_dir="/run/user/$(id -u)"

    # ── Core processes ──────────────────────────────────────────────────
    apps="omd-bar omd-polkit"

    # ── Registry-driven application modules ──────────────────────────────
    _registry_file="${SUMIKA_MODULE_REGISTRY:-${SUMIKA_SHELL_RUNTIME_DIR:-/run/user/$(id -u)/sumika-shell}/modules.json}"
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

    # ── Stop all units (parallel, capped, force-killed) ─────────────────
    # omd-bar must be stopped synchronously and WITHOUT SIGKILL to avoid
    # a self-kill race: omd-restart runs in omd-bar's cgroup (spawned by
    # the bar's Quickshell).  KillMode=mixed ensures systemctl stop only
    # SIGTERMs the main PID; our child process survives as an orphan.
    # Start all OTHER units in parallel first, then handle omd-bar.
    for app in $apps; do
        if [ "$app" = "omd-bar" ]; then
            continue
        fi
        (
            timeout 3 systemctl --user stop "$app.service" 2>/dev/null || true
            systemctl --user kill --signal=SIGKILL --kill-who=all "$app.service" 2>/dev/null || true
        ) &
    done
    # omd-bar — synchronous, no SIGKILL (would kill omd-restart itself)
    timeout 3 systemctl --user stop omd-bar.service 2>/dev/null || true
    wait
    sleep 0.2

    # ── Orphan process cleanup (survived reparenting or never in cgroup) ─
    pkill -f "wl-paste --watch" 2>/dev/null || true
    pkill -f "omd-clipboard-store" 2>/dev/null || true
    # Remove stale PID file so the next daemon instance doesn't see a
    # "still running" guard hit (race: pkill returns before the killed
    # process has fully exited).
    rm -f /tmp/omd-clipboard-store.pid 2>/dev/null || true

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

    # ── Orphan Quickshell processes ─────────────────────────────────────
    pkill -f "/usr/bin/quickshell -p ${omd_root}/" 2>/dev/null || true
    sleep 0.15

    # ── Reset unit state for clean restart ──────────────────────────────
    for app in $apps; do
        systemctl --user reset-failed "$app.service" >/dev/null 2>&1 || true
        rm -f "$runtime_dir/systemd/transient/$app.service" 2>/dev/null || true
    done
    systemctl --user daemon-reload >/dev/null 2>&1 || true
}
