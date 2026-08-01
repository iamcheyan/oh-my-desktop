pragma Singleton
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

    function suspend(saveCurrentSession) {
        Quickshell.execDetached(["bash", "-lc", withOptionalSessionSave("systemctl suspend || loginctl suspend", saveCurrentSession)]);
    }

    function withOptionalSessionSave(command, saveCurrentSession) {
        // save-auto-if-stale avoids overwriting a snapshot written moments
        // ago (e.g. the systemd fallback already ran). It still arms
        // restore-on-next-start if the UI save is the only path.
        return (saveCurrentSession ? `"${Directories.root}/bin/sumika-session" save-auto-if-stale && ` : "") + command;
    }

    function logout(saveCurrentSession) {
        Quickshell.execDetached(["bash", "-lc", withOptionalSessionSave(`"${Directories.root}/bin/sumika-logout"`, saveCurrentSession)]);
    }

    function launchTaskManager() {
        Quickshell.execDetached(["bash", "-c", `${Config.options.apps.taskManager}`]);
    }

    function hibernate(saveCurrentSession) {
        Quickshell.execDetached(["bash", "-lc", withOptionalSessionSave(`systemctl hibernate || loginctl hibernate`, saveCurrentSession)]);
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
