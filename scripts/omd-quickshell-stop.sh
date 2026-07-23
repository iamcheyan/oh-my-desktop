#!/bin/sh
# Stop OMD Quickshell processes without killing unrelated apps in unit cgroups.
#
# Foot terminals, tmux, and other apps launched from omd-applauncher inherit its
# systemd cgroup. `systemctl stop` tears down the whole cgroup, so we only signal
# the unit main process and rely on targeted pkill for the quickshell binary.

omd_stop_quickshell() {
    omd_root="${OMD_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
    runtime_dir="/run/user/$(id -u)"
    # Processes whose dir name differs from their unit/process name use DIRECT_* maps.
    apps="omd-notification omd-bar omd-overview omd-polkit omd-applauncher omd-clipboard omd-clipboard-store"
    apps_dir="omd-notification omd-bar overview omd-polkit omd-applauncher omd-clipboard omd-clipboard-store"
    legacy_apps="omd-desktop"

    for app_dir in $apps_dir; do
        pkill -f "(quickshell|qs).* -p ${omd_root}/(apps|modules)/${app_dir}( |$)" 2>/dev/null || true
    done

    # Quickshell Process children can survive `systemctl --user kill --kill-who=main`
    # because we intentionally avoid tearing down the whole unit cgroup. Clean up
    # known OMD watcher processes so repeated `omd-restart` calls do not stack them.
    pkill -f "(^|/)nmcli monitor$" 2>/dev/null || true
    pkill -f "wl-paste --watch.*cliphist" 2>/dev/null || true
    pkill -f "wl-paste .*--watch.*cliphist" 2>/dev/null || true
    pkill -f "wl-paste --type text --watch cliphist store" 2>/dev/null || true
    pkill -f "wl-paste --type image --watch cliphist store" 2>/dev/null || true
    sleep 0.3

    pkill -9 -f "(quickshell|qs).* -p ${omd_root}/(apps|modules)/omd-" 2>/dev/null || true

    for app in $apps; do
        systemctl --user kill --kill-who=main "$app.service" 2>/dev/null || true
    done
    for app in $legacy_apps; do
        systemctl --user kill --kill-who=main "$app.service" 2>/dev/null || true
    done
    sleep 0.2

    for app in $apps; do
        systemctl --user reset-failed "$app.service" >/dev/null 2>&1 || true
        rm -f "$runtime_dir/systemd/transient/$app.service" 2>/dev/null || true
    done
    for app in $legacy_apps; do
        systemctl --user reset-failed "$app.service" >/dev/null 2>&1 || true
        rm -f "$runtime_dir/systemd/transient/$app.service" 2>/dev/null || true
    done
    systemctl --user daemon-reload >/dev/null 2>&1 || true
}
