#!/bin/sh
# Stop OMD Quickshell processes without killing unrelated apps in unit cgroups.
#
# Foot terminals, tmux, and other apps launched from omd-applauncher inherit its
# systemd cgroup. `systemctl stop` tears down the whole cgroup, so we only signal
# the unit main process and rely on targeted pkill for the quickshell binary.

omd_stop_quickshell() {
    omd_root="${OMD_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
    runtime_dir="/run/user/$(id -u)"

    # ── Core host processes (always required) ────────────────────────────
    # omd-bar and omd-polkit are Core host processes, not discovered modules.
    # Their directories are under apps/.
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

    # Quickshell Process children can survive `systemctl --user kill --kill-who=main`
    # because we intentionally avoid tearing down the whole unit cgroup. Clean up
    # known watcher processes from module manifests so repeated `omd-restart` calls
    # do not stack them.
    #
    # Registry-driven cleanup: modules declare `watchers: ["cmd1", "cmd2"]` in their
    # module.json entry. If the registry file is unavailable, fall back to known
    # legacy watchers for backwards compatibility.
    _cleaned=false
    if command -v jq >/dev/null 2>&1 && [ -f "$_registry_file" ]; then
        while IFS="" read -r watcher; do
            [ -z "$watcher" ] && continue
            pkill -f "$watcher" 2>/dev/null || true
            _cleaned=true
        done <<WATCHERS
$(jq -r '
  .modules[] |
  select(.contributes.watchers? // [] | length > 0) |
  .contributes.watchers[]
' "$_registry_file" 2>/dev/null || true)
WATCHERS
    fi
    if [ "$_cleaned" != "true" ]; then
        # Legacy fallback: known OMD watcher processes.
        pkill -f "(^|/)nmcli monitor$" 2>/dev/null || true
        pkill -f "wl-paste --watch.*cliphist" 2>/dev/null || true
    fi
    for app in $apps; do
        systemctl --user kill --kill-who=main "$app.service" 2>/dev/null || true
    done
    sleep 0.2

    # Targeted cleanup for any remaining OMD Quickshell processes (orphans from
    # previous unit names, failed stops, or path-based launches). Do not use a
    # bare `pkill quickshell` — only configs under this repo / known roots.
    pkill -f "/usr/bin/quickshell -p ${omd_root}/" 2>/dev/null || true
    if [ -n "${SUMIKA_MODULES_HOME:-}" ]; then
        pkill -f "/usr/bin/quickshell -p ${SUMIKA_MODULES_HOME}/" 2>/dev/null || true
    fi
    sleep 0.15

    for app in $apps; do
        systemctl --user reset-failed "$app.service" >/dev/null 2>&1 || true
        rm -f "$runtime_dir/systemd/transient/$app.service" 2>/dev/null || true
    done
    systemctl --user daemon-reload >/dev/null 2>&1 || true
}
