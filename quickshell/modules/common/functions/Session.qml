pragma Singleton
pragma ComponentBehavior: Bound
import qs
import Quickshell
import qs.services
import qs.core.runtime
import qs.modules.common

Singleton {
    id: root

    function closeAllWindows() {
        // Use Hyprland's Lua dispatch so applications get a chance to save
        // state (e.g. editor prompts, browser session restore). Killing with
        // SIGKILL loses unsaved work.
        ServiceManager.workspace.windowList.forEach(w => {
            if (w.address)
                Quickshell.execDetached(["hyprctl", "dispatch", `hl.dsp.window.close({window = "address:${w.address}"})`]);
        });
    }

    function changePassword() {
        Quickshell.execDetached(["bash", "-c", `${Config.options.apps.changePassword}`]);
    }

    function lock() {
        LockService.lock();
    }

    function restoreIfEmpty() {
        // Restore the saved snapshot only when the desktop is empty, so a
        // manual "Restore Snapshot" does not pile windows onto a running
        // session. Compositor-agnostic: Hyprland via hyprctl, labwc via
        // wlrctl (foreign-toplevel lists app toplevels only, not shell
        // surfaces like the bar). A failing tool (empty output) counts as
        // non-empty to be safe.
        Quickshell.execDetached(["bash", "-c",
            `if pgrep -x labwc >/dev/null 2>&1; then `
            + `clients=$(wlrctl toplevel list 2>/dev/null | wc -l); `
            + `else clients=$(hyprctl -j clients | jq 'length' 2>/dev/null || echo 0); `
            + `fi; `
            + `if [ -z "$clients" ] || [ "$clients" -gt 0 ]; then `
            + `echo "Workspace not empty ($clients windows) — restore cancelled"; `
            + `else "${Directories.root}/bin/sumika-session" restore; fi`
        ]);
    }

    function suspend(saveCurrentSession) {
        // Route through sumika-keep-awake so an active Keep Awake inhibitor
        // (which only guards automatic suspend triggers) is lifted for this
        // explicit request and re-armed after resume.
        Quickshell.execDetached(["bash", "-lc", withOptionalSessionSave(`"${Directories.root}/bin/sumika-keep-awake" suspend`, saveCurrentSession)]);
    }

    function withOptionalSessionSave(command, saveCurrentSession) {
        // When the user checks "save current session", write the
        // save-requested flag first so the systemd/logout fallback knows to
        // arm restore even if its own save() finds the compositor gone.
        // save-auto-if-stale avoids overwriting a snapshot written moments
        // ago (e.g. the fallback already ran) and consumes the flag. The
        // command runs regardless of save outcome (&& vs ||) so a save
        // failure never blocks logout/shutdown.
        return (saveCurrentSession
            ? `"${Directories.root}/bin/sumika-session" save-requested; "${Directories.root}/bin/sumika-session" save-auto-if-stale; `
            : "") + command;
    }

    function logout(saveCurrentSession) {
        Quickshell.execDetached(["bash", "-lc", withOptionalSessionSave(`"${Directories.root}/bin/sumika-logout"`, saveCurrentSession)]);
    }

    function launchTaskManager() {
        Quickshell.execDetached(["bash", "-c", `${Config.options.apps.taskManager}`]);
    }

    function hibernate(saveCurrentSession) {
        // See suspend(): bypass Keep Awake for explicit hibernate requests.
        Quickshell.execDetached(["bash", "-lc", withOptionalSessionSave(`"${Directories.root}/bin/sumika-keep-awake" hibernate`, saveCurrentSession)]);
    }

    function poweroff(saveCurrentSession) {
        if (!saveCurrentSession)
            closeAllWindows();
        Quickshell.execDetached(["bash", "-lc", withOptionalSessionSave("systemctl poweroff || loginctl poweroff", saveCurrentSession)]);
    }

    function reboot(saveCurrentSession) {
        if (!saveCurrentSession)
            closeAllWindows();
        Quickshell.execDetached(["bash", "-lc", withOptionalSessionSave("reboot || loginctl reboot", saveCurrentSession)]);
    }

    function rebootToFirmware() {
        closeAllWindows();
        Quickshell.execDetached(["bash", "-c", `systemctl reboot --firmware-setup || loginctl reboot --firmware-setup`]);
    }
}
