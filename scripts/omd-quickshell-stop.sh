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
    # ── Preserve user apps: move cgroup children to a holding scope ──────
    # omd-bar.service's cgroup contains user apps (terminals, Firefox, etc.)
    # launched from the bar/launcher. `systemctl stop` destroys the cgroup,
    # killing everything inside. Before stopping, move non-quickshell PIDs
    # to a transient scope so they survive the reload.
    _bar_cg="/sys/fs/cgroup$(systemctl --user show omd-bar.service -p ControlGroup --value 2>/dev/null || echo '')"
    if [ -n "$_bar_cg" ] && [ -f "$_bar_cg/cgroup.procs" ]; then
        _ts=$(date +%s%N 2>/dev/null || date +%s)
        _hold_unit="omd-survivors-$_ts"
        # Create a transient scope that stays alive (sleep) to hold survivors.
        systemd-run --user --unit="$_hold_unit" \
            --property=KillMode=process \
            /bin/sh -c 'exec sleep infinity' >/dev/null 2>&1 || true
        _hold_cg="/sys/fs/cgroup$(systemctl --user show "$_hold_unit.service" -p ControlGroup --value 2>/dev/null || echo '')"
        if [ -n "$_hold_cg" ] && [ -d "$_hold_cg" ]; then
            # Move all non-quickshell PIDs from omd-bar cgroup to the hold scope.
            while IFS= read -r _pid; do
                [ -z "$_pid" ] && continue
                _cmd=$(cat "/proc/$_pid/cmdline" 2>/dev/null | tr '\0' ' ' | head -c 80)
                case "$_cmd" in
                    *quickshell*|*nmcli*|"")
                        # Quickshell main or bar-internal process — let it die.
                        ;;
                    *)
                        # User app — move to holding scope.
                        echo "$_pid" > "$_hold_cg/cgroup.procs" 2>/dev/null || true
                        ;;
                esac
            done < "$_bar_cg/cgroup.procs"
        fi
    fi

    # ── Stop all units — now safe, user apps are in the holding scope ────
    for app in $apps; do
        timeout 3 systemctl --user stop "$app.service" 2>/dev/null || true
    done
    wait
    sleep 0.2

    # ── Orphan process cleanup ──────────────────────────────────────────
    _clipboard_module=""
    if command -v jq >/dev/null 2>&1 && [ -f "$_registry_file" ]; then
        _clipboard_module=$(jq -r '.modules[] | select(.id == "clipboard") | .path // empty' "$_registry_file" 2>/dev/null || true)
    fi
    if [ -n "$_clipboard_module" ] && [ -x "$_clipboard_module/bin/omd-clipboard-store" ]; then
        "$_clipboard_module/bin/omd-clipboard-store" stop >/dev/null 2>&1 || true
    fi

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

    # Orphan Quickshell processes not in any unit
    pkill -f "/usr/bin/quickshell -p ${omd_root}/" 2>/dev/null || true
    sleep 0.15

    # ── Reset unit state for clean restart ──────────────────────────────
    for app in $apps; do
        systemctl --user reset-failed "$app.service" >/dev/null 2>&1 || true
        rm -f "$runtime_dir/systemd/transient/$app.service" 2>/dev/null || true
    done
    systemctl --user daemon-reload >/dev/null 2>&1 || true
}
