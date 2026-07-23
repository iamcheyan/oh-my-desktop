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
    apps_dir="omd-bar omd-polkit"

    # ── Registry-driven application modules ──────────────────────────────
    _registry_file="${SUMIKA_MODULE_REGISTRY:-${SUMIKA_SHELL_RUNTIME_DIR:-/run/user/$(id -u)/sumika-shell}/modules.json}"
    if command -v jq >/dev/null 2>&1 && [ -f "$_registry_file" ]; then
        while IFS=" " read -r instance module_id; do
            [ -z "$instance" ] && continue
            apps="$apps $instance"

            # Determine the app directory: prefer OMD_ROOT/modules/<id>,
            # fall back to apps/<instance> for reverse compatibility.
            if [ -d "$omd_root/modules/$module_id" ]; then
                apps_dir="$apps_dir $module_id"
            elif [ -d "$omd_root/apps/$instance" ]; then
                apps_dir="$apps_dir $instance"
            elif [ -d "$omd_root/modules/$instance" ]; then
                apps_dir="$apps_dir $instance"
            else
                # External module: use instance name for pkill pattern.
                apps_dir="$apps_dir $instance"
            fi
        done <<EOF
$(jq -r '
  .modules[] |
  select(.kind == "application" and (.entry | length > 0)) |
  "\(.entry.instance // .id) \(.id)"
' "$_registry_file" 2>/dev/null || true)
EOF
    fi

    # ── Kill each module's quickshell instance ─────────────────────────────
    for app_dir in $apps_dir; do
        pkill -f "(quickshell|qs).* -p ${omd_root}/(apps|modules)/${app_dir}( |$)" 2>/dev/null || true
    done
    for instance in $apps; do
        pkill -f "(quickshell|qs).* -p .*/${instance}( |$)" 2>/dev/null || true
    done
    # ── Kill clipboard-store watchers (shim-managed, no systemd unit) ───────
    # Phase J: remove when clipboard module declares kind=application + entry
    pkill -f "wl-paste --watch.*cliphist" 2>/dev/null || true

    # Quickshell Process children can survive `systemctl --user kill --kill-who=main`
    # because we intentionally avoid tearing down the whole unit cgroup. Clean up
    # known OMD watcher processes so repeated `omd-restart` calls do not stack them.
    pkill -f "(^|/)nmcli monitor$" 2>/dev/null || true

    for app in $apps; do
        systemctl --user kill --kill-who=main "$app.service" 2>/dev/null || true
    done
    sleep 0.2

    for app in $apps; do
        systemctl --user reset-failed "$app.service" >/dev/null 2>&1 || true
        rm -f "$runtime_dir/systemd/transient/$app.service" 2>/dev/null || true
    done
    systemctl --user daemon-reload >/dev/null 2>&1 || true
}
