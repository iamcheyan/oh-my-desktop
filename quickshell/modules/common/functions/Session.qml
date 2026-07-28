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

    function suspend() {
        Quickshell.execDetached(["bash", "-c", "systemctl suspend || loginctl suspend"]);
    }

    function withOptionalSessionSave(command, saveCurrentSession) {
        return (saveCurrentSession ? `"${Directories.root}/bin/sumika-session" save-auto && ` : "") + command;
    }

    function logout(saveCurrentSession) {
        Quickshell.execDetached(["bash", "-lc", withOptionalSessionSave(`"${Directories.root}/bin/sumika-logout"`, saveCurrentSession)]);
    }

    function launchTaskManager() {
        Quickshell.execDetached(["bash", "-c", `${Config.options.apps.taskManager}`]);
    }

    function hibernate() {
        Quickshell.execDetached(["bash", "-c", `systemctl hibernate || loginctl hibernate`]);
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
