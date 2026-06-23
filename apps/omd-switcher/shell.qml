//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_IM_MODULE=fcitx

import "modules/common"
import qs.modules.common.functions

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

ShellRoot {
    id: root

    readonly property string overviewApp: `${FileUtils.trimFileProtocol(Directories.config)}/omd/apps/omd-overview`
    property real lastShortcut: 0

    function relay(method) {
        Quickshell.execDetached([
            "qs", "-p", root.overviewApp, "ipc", "call", "switcher", method
        ]);
    }

    function throttledRelay(method) {
        const now = Date.now();
        if (now - root.lastShortcut < 150)
            return;
        root.lastShortcut = now;
        root.relay(method);
    }

    IpcHandler {
        target: "switcher"

        function next() {
            root.relay("next");
        }
        function prev() {
            root.relay("prev");
        }
        function commit() {
            root.relay("commit");
        }
    }

    GlobalShortcut {
        name: "switcherNext"
        description: "Workspace switcher: cycle next (Win+Tab)"
        onPressed: root.throttledRelay("next")
    }
    GlobalShortcut {
        name: "switcherPrev"
        description: "Workspace switcher: cycle prev (Win+Shift+Tab)"
        onPressed: root.throttledRelay("prev")
    }
    GlobalShortcut {
        name: "switcherCommit"
        description: "Workspace switcher: commit on Win release"
        onPressed: root.relay("commit")
    }
}
