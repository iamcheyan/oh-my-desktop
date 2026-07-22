// SessionPopup.qml — Session save/restore popup.
import qs
import qs.modules.common
import qs.modules.common.functions
import qs.modules.bar
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

ColumnLayout {
    id: popup
    spacing: 0
    width: parent?.width ?? implicitWidth
    readonly property string omdSession: Directories.config.startsWith("file://")
        ? `${FileUtils.trimFileProtocol(Directories.config)}/omd/bin/omd-session`
        : `${Directories.config}/omd/bin/omd-session`
    readonly property string snapshotFile: `${Directories.sumikaStateHome}/session/last.json`
    property bool hasSnapshot: false
    property int snapshotCount: 0
    property bool canvasEmpty: ToplevelManager.toplevels.values.length === 0

    FileView {
        path: popup.snapshotFile
        onLoaded: {
            try {
                const data = JSON.parse(text());
                const count = Array.isArray(data.clients) ? data.clients.length : 0;
                popup.hasSnapshot = count > 0;
                popup.snapshotCount = count;
            } catch (e) {
                popup.hasSnapshot = false;
                popup.snapshotCount = 0;
            }
        }
        onLoadFailed: {
            popup.hasSnapshot = false;
            popup.snapshotCount = 0;
        }
    }

    PopupHeader {
        Layout.fillWidth: true
        icon: NerdIconMap.workspaceSnapshot
        title: "Session"
        subtitle: popup.canvasEmpty ? "No windows open"
            : `${ToplevelManager.toplevels.values.length} window${ToplevelManager.toplevels.values.length === 1 ? "" : "s"} open`
        tone: popup.canvasEmpty ? TuiStyle.muted : TuiStyle.success
    }

    PopupInfoRow {
        label: "Saved snapshot"
        value: popup.hasSnapshot ? `${popup.snapshotCount} windows` : "None"
        valueColor: popup.hasSnapshot ? TuiStyle.accent : TuiStyle.dim
        showDivider: false
    }

    IconActionRow {
        PopupIconButton {
            icon: NerdIconMap.workspaceSnapshot
            label: "Save"
            accent: TuiStyle.info
            enabledState: !popup.canvasEmpty || popup.hasSnapshot
            onClicked: saveSessionSnapshot()
        }
        PopupIconButton {
            icon: NerdIconMap.close
            label: "Save & Close"
            accent: TuiStyle.warning
            enabledState: !popup.canvasEmpty || popup.hasSnapshot
            onClicked: { GlobalStates.barPopupType = ""; Quickshell.execDetached([popup.omdSession, "save-close"]); }
        }
        PopupIconButton {
            icon: NerdIconMap.refresh
            label: "Restore"
            accent: TuiStyle.accent
            enabledState: popup.hasSnapshot
            onClicked: { GlobalStates.barPopupType = ""; Quickshell.execDetached([popup.omdSession, "restore"]); }
        }
    }

    function saveSessionSnapshot() {
        Quickshell.execDetached([popup.omdSession, "save"]);
        popup.hasSnapshot = true;
        popup.snapshotCount = ToplevelManager.toplevels.values.length;
    }
}
