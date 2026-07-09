import qs
import qs.modules.bar
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Item {
    id: root
    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
    Layout.fillHeight: true
    implicitWidth: Config.options.bar.rightIconSlotWidth
    implicitHeight: Config.options.bar.rightIconSlotWidth

    property bool hasSnapshot: false
    property int snapshotCount: 0
    // canvasEmpty is driven by the live Wayland toplevel manager instead of
    // spawning `hyprctl -j clients | jq` every 5 seconds. ToplevelManager
    // tracks mapped windows automatically and emits changes on its own.
    property bool canvasEmpty: ToplevelManager.toplevels.values.length === 0
    property var previewData: ({ count: 0, workspaceCount: 0, workspaces: [] })
    readonly property string omdSession: `${FileUtils.trimFileProtocol(Directories.config)}/omd/bin/omd-session`

    function refreshStatus() {
        statusProc.running = false;
        statusProc.running = true;
    }

    Component.onCompleted: refreshStatus()

    Timer {
        // Refresh the snapshot status only while the session menu is open.
        // The canvas (mapped windows) state is tracked live via
        // ToplevelManager, so no background poll is needed for it.
        id: statusPollTimer
        interval: 5000
        repeat: true
        running: sessionMenu.active
        onTriggered: root.refreshStatus()
    }

    Timer {
        id: refreshSoon
        interval: 900
        repeat: false
        onTriggered: root.refreshStatus()
    }

    Process {
        id: statusProc
        command: [root.omdSession, "status"]
        running: false
        stdout: StdioCollector {
            id: statusCollector
            onStreamFinished: {
                try {
                    const data = JSON.parse(statusCollector.text);
                    root.hasSnapshot = data.saved === true;
                    root.snapshotCount = data.count || 0;
                } catch (e) {
                    root.hasSnapshot = false;
                    root.snapshotCount = 0;
                }
            }
        }
    }

    Process {
        id: previewProc
        command: [root.omdSession, "preview"]
        running: false
        stdout: StdioCollector {
            id: previewCollector
            onStreamFinished: {
                try {
                    root.previewData = JSON.parse(previewCollector.text);
                    previewLoader.active = true;
                } catch (e) {
                    root.previewData = ({ count: 0, workspaceCount: 0, workspaces: [] });
                }
            }
        }
    }

    RippleButton {
        id: sessionButton
        anchors.centerIn: parent
        width: Config.options.bar.rightIconSlotWidth
        height: Config.options.bar.rightIconSlotWidth
        buttonRadius: Appearance.rounding.full
        colBackground: ColorUtils.transparentize(Appearance.colors.colLayer1Hover, 1)
        colBackgroundHover: ColorUtils.transparentize(Appearance.colors.colLayer1Hover, 1)
        colRipple: ColorUtils.transparentize(Appearance.colors.colLayer1Active, 1)

        onClicked: sessionMenu.open()
    }

    BarNerdIcon {
        anchors.centerIn: sessionButton
        text: NerdIconMap.workspaceSnapshot
        color: root.canvasEmpty && root.hasSnapshot ? TuiStyle.accent : Appearance.colors.colBarText
    }

    Loader {
        id: sessionMenu
        function open() {
            root.refreshStatus();
            if (sessionMenu.item) {
                sessionMenu.item.open();
            } else {
                sessionMenu.active = true;
            }
        }
        active: false
        sourceComponent: SessionContextMenu {
            hasSnapshot: root.hasSnapshot
            snapshotCount: root.snapshotCount
            canvasEmpty: root.canvasEmpty
            sessionCommand: root.omdSession
            Component.onCompleted: this.open()
            anchor {
                window: sessionButton.QsWindow.window
                item: sessionButton
                gravity: Config.options.bar.vertical
                    ? (Config.options.bar.bottom ? Edges.Left : Edges.Right)
                    : (Config.options.bar.bottom ? Edges.Top : Edges.Bottom)
                edges: Config.options.bar.vertical
                    ? (Config.options.bar.bottom ? Edges.Left : Edges.Right)
                    : (Config.options.bar.bottom ? Edges.Top : Edges.Bottom)
            }
            onActionTriggered: refreshSoon.restart()
            onPreviewRequested: {
                previewProc.running = false;
                previewProc.running = true;
            }
            onRestoreRequested: {
                restoreLoader.active = true;
            }
            onMenuClosed: sessionMenu.active = false
        }
    }

    Loader {
        id: previewLoader
        active: false
        sourceComponent: SessionPreviewPopup {
            previewData: root.previewData
            sessionCommand: root.omdSession
            anchor {
                window: sessionButton.QsWindow.window
                item: sessionButton
                gravity: Config.options.bar.vertical
                    ? (Config.options.bar.bottom ? Edges.Left : Edges.Right)
                    : (Config.options.bar.bottom ? Edges.Top : Edges.Bottom)
                edges: Config.options.bar.vertical
                    ? (Config.options.bar.bottom ? Edges.Left : Edges.Right)
                    : (Config.options.bar.bottom ? Edges.Top : Edges.Bottom)
            }
            onConfirmed: {
                previewLoader.active = false;
                refreshSoon.restart();
            }
            onDismissed: previewLoader.active = false
        }
    }

    Loader {
        id: restoreLoader
        active: false
        sourceComponent: SessionRestoreOverlay {
            sessionCommand: root.omdSession
            expectedCount: root.snapshotCount
            onFinished: {
                restoreLoader.active = false;
                refreshSoon.restart();
            }
        }
    }
}
