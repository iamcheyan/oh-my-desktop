import qs
import qs.modules.bar
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: root
    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
    Layout.fillHeight: true
    implicitWidth: Config.options.bar.rightIconSlotWidth
    implicitHeight: Config.options.bar.rightIconSlotWidth

    property bool hasSnapshot: false
    property int snapshotCount: 0
    property bool canvasEmpty: true
    readonly property string omdSession: `${FileUtils.trimFileProtocol(Directories.config)}/omd/bin/omd-session`

    function refreshStatus() {
        statusProc.running = false;
        statusProc.running = true;
        clientCountProc.running = false;
        clientCountProc.running = true;
    }

    Component.onCompleted: refreshStatus()

    Timer {
        interval: 5000
        repeat: true
        running: true
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
        id: clientCountProc
        command: ["bash", "-c", "hyprctl -j clients | jq '[.[] | select((.hidden // false) | not)] | length'"]
        running: false
        stdout: StdioCollector {
            id: clientCountCollector
            onStreamFinished: {
                try {
                    const n = parseInt(clientCountCollector.text.trim()) || 0;
                    root.canvasEmpty = n === 0;
                } catch (e) {
                    root.canvasEmpty = false;
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

        contentItem: BarNerdIcon {
            text: NerdIconMap.workspaceSnapshot
            color: root.canvasEmpty && root.hasSnapshot ? TuiStyle.accent : Appearance.colors.colBarText
        }

        onClicked: sessionMenu.open()
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
            onMenuClosed: sessionMenu.active = false
        }
    }
}
